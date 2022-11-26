import BSONEncoding
import MongoWire
import NIOCore
import NIOPosix
import NIOSSL
import SCRAM
import SHA2

extension Mongo
{
    /// @import(NIOCore)
    /// A connection to a `mongod`/`mongos` host that we have completed an initial
    /// handshake with.
    ///
    /// > Warning: This type is not managed! If you are storing instances of this type, 
    /// there must be code elsewhere responsible for closing the wrapped NIO ``Channel``!
    @frozen public
    struct Connection:Sendable
    {
        private
        let channel:any Channel
        let instance:Instance

        private
        init(instance:Instance, channel:any Channel)
        {
            self.instance = instance
            self.channel = channel
        }
        func close()
        {
            self.channel.close(mode: .all, promise: nil)
        }
    }
}
extension Mongo.Connection
{
    static
    func connect(to host:Mongo.Host, settings:Mongo.ConnectionSettings,
        resolver:(some Resolver)?,
        group:any EventLoopGroup) async throws -> Self
    {
        let channel:any Channel = try await Self.channel(to: host, settings: settings,
            resolver: resolver,
            group: group)
        do
        {
            return try await .init(channel: channel, credentials: settings.credentials)
        }
        catch let error
        {
            try await channel.close()
            throw error
        }
    }

    /// Reinitializes a connection, performing authentication with the given credentials,
    /// if possible.
    mutating
    func reinit(credentials:Mongo.Credentials?) async throws
    {
        self = try await .init(channel: self.channel, credentials: credentials)
    }
}
extension Mongo.Connection
{
    private static
    func channel(to host:Mongo.Host, settings:Mongo.ConnectionSettings,
        resolver:(some Resolver)?,
        group:any EventLoopGroup) async throws -> any Channel
    {
        let bootstrap:ClientBootstrap = .init(group: group)
            .resolver(resolver)
            .channelOption(ChannelOptions.socket(SocketOptionLevel.init(SOL_SOCKET), SO_REUSEADDR), 
                value: 1)
            .channelInitializer 
        { 
            (channel:any Channel) in

            let wire:ByteToMessageHandler<Mongo.MessageDecoder> = .init(.init())
            let router:Mongo.MessageRouter = .init(timeout: settings.timeout)

            guard let tls:Mongo.ConnectionSettings.TLS = settings.tls
            else
            {
                return channel.pipeline.addHandlers(wire, router)
            }
            do 
            {
                var configuration:TLSConfiguration = .clientDefault
                configuration.trustRoots = NIOSSLTrustRoots.file(tls.certificatePath)
                
                let tls:NIOSSLClientHandler = try .init(
                    context: .init(configuration: configuration), 
                    serverHostname: host.name)
                return channel.pipeline.addHandlers(tls, wire, router)
            } 
            catch let error
            {
                return channel.eventLoop.makeFailedFuture(error)
            }
        }
        
        return try await bootstrap.connect(host: host.name, port: host.port).get()
    }

    /// Initializes a connection, performing authentication with the given credentials,
    /// if possible.
    private
    init(channel:any Channel, credentials:Mongo.Credentials?) async throws
    {
        let message:MongoWire.Message<ByteBufferView> = try await withCheckedThrowingContinuation
        {
            (continuation:CheckedContinuation<MongoWire.Message<ByteBufferView>, any Error>) in

            let hello:Mongo.Hello
            // if we don’t have an explicit authentication mode, ask the server
            // what it supports (for the current user).
            if  let credentials:Mongo.Credentials,
                case nil = credentials.authentication
            {
                hello = .init(user: credentials.user)
            } 
            else
            {
                hello = .init(user: nil)
            }
            var command:BSON.Fields = .init(with: hello.encode(to:))
                command.add(database: .admin)
            
            channel.writeAndFlush((command, continuation), promise: nil)
        }

        self.init(instance: try Mongo.Hello.decode(message: message), channel: channel)

        guard let credentials:Mongo.Credentials
        else
        {
            return
        }
        do
        {
            try await self.authenticate(with: credentials)
        }
        catch let error
        {
            throw Mongo.AuthenticationError.init(error, credentials: credentials)
        }
    }
}

extension Mongo.Connection
{
    private
    func authenticate(with credentials:Mongo.Credentials) async throws
    {
        let sasl:Mongo.Authentication.SASL
        switch credentials.authentication
        {
        case .sasl(let explicit)?:
            //  https://github.com/mongodb/specifications/blob/master/source/auth/auth.rst
            //  '''
            //  When a user has specified a mechanism, regardless of the server version,
            //  the driver MUST honor this.
            //  '''
            sasl = explicit
        
        case let other?:
            throw Mongo.AuthenticationUnsupportedError.init(other)
        
        case nil:
            //  '''
            //  If SCRAM-SHA-256 is present in the list of mechanism, then it MUST be used
            //  as the default; otherwise, SCRAM-SHA-1 MUST be used as the default,
            //  regardless of whether SCRAM-SHA-1 is in the list. Drivers MUST NOT attempt
            //  to use any other mechanism (e.g. PLAIN) as the default.
            //
            //  If `saslSupportedMechs` is not present in the handshake response for
            //  mechanism negotiation, then SCRAM-SHA-1 MUST be used when talking to
            //  servers >= 3.0. Prior to server 3.0, MONGODB-CR MUST be used.
            //  '''
            if case true? = self.instance.saslSupportedMechs?.contains(.sha256)
            {
                sasl = .sha256
            }
            else
            {
                sasl = .sha1
            }
        }

        switch sasl
        {
        case .sha256:
            try await self.authenticate(sasl: .sha256,
                database: credentials.database,
                username: credentials.username,
                password: credentials.password)
        
        case .sha1:
            // note: we need to hash the password per
            // https://github.com/mongodb/specifications/blob/master/source/auth/auth.rst#scram-sha-1
            throw Mongo.AuthenticationUnsupportedError.init(.sasl(.sha1))
        
        case let other:
            throw Mongo.AuthenticationUnsupportedError.init(.sasl(other))
        }
    } 
    private
    func authenticate(sasl mechanism:Mongo.Authentication.SASL, 
        database:Mongo.Database, 
        username:String, 
        password:String) async throws 
    {
        let start:SCRAM.Start = .init(username: username)
        let first:Mongo.SASLResponse = try await self.run(
            command: Mongo.SASLStart.init(mechanism: mechanism, scram: start),
            against: database)
        
        if  first.done 
        {
            return
        }

        let challenge:SCRAM.Challenge = try .init(from: first.message)
        //  https://github.com/mongodb/specifications/blob/master/source/auth/auth.rst
        //  '''
        //  Additionally, drivers MUST enforce a minimum iteration count of 4096 and
        //  MUST error if the authentication conversation specifies a lower count.
        //  This mitigates downgrade attacks by a man-in-the-middle attacker.
        //  '''
        guard 4096 ... 310_000 ~= challenge.iterations
        else
        {
            throw Mongo.PolicyError.sha256Iterations(challenge.iterations)
        }

        let client:SCRAM.ClientResponse<SHA256> = try .init(challenge: challenge,
            password: password,
            received: first.message,
            sent: start)
        let second:Mongo.SASLResponse = try await self.run(
            command: first.command(message: client.message),
            against: database)
        
        let server:SCRAM.ServerResponse = try .init(from: second.message)

        guard client.verify(server)
        else
        {
            throw Mongo.PolicyError.serverSignature
        }

        if  second.done 
        {
            return
        }
        
        let third:Mongo.SASLResponse = try await self.run(
            command: second.command(message: .init("")),
            against: database)
        
        guard third.done
        else 
        {
            throw Mongo.SASLConversationError.init()
        }
    }
}


extension Mongo.Connection:Identifiable
{
    public
    var id:Mongo.ConnectionIdentifier
    {
        self.instance.connection
    }
}
extension Mongo.Connection
{
    var closeFuture:EventLoopFuture<Void> 
    {
        self.channel.closeFuture
    }
}

extension Mongo.Connection
{
    /// Runs an authentication command against the specified `database`.
    func run<Command>(command:__owned Command,
        against database:Mongo.Database) async throws -> Mongo.SASLResponse
        where Command:MongoAuthenticationCommand
    {
        try Command.decode(message: try await self.run(command: command,
            against: database,
            session: nil))
    }
    func run(command:__owned some MongoCommand,
        against database:Mongo.Database,
        transaction:Never? = nil,
        session:Mongo.Session.ID?) async throws -> MongoWire.Message<ByteBufferView>
    {
        var command:BSON.Fields = .init(with: command.encode(to:))
            command.add(database: database)
        
        if let session:Mongo.Session.ID
        {
            command.add(session: session)
        }
        
        // if let transaction:Mongo.Transaction 
        // {
        //     command.appendValue(transaction.number, forKey: "txnNumber")
        //     command.appendValue(transaction.autocommit, forKey: "autocommit")

        //     if await transaction.startTransaction() 
        //     {
        //         command.appendValue(true, forKey: "startTransaction")
        //     }
        // }
        
        return try await withCheckedThrowingContinuation
        {
            (continuation:CheckedContinuation<MongoWire.Message<ByteBufferView>, any Error>) in

            self.channel.writeAndFlush((command, continuation), promise: nil)
        }
    }
}
