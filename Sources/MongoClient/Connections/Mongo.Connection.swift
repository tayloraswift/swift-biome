import BSONEncoding
import Foundation
import _MongoKittenCrypto
import DNSClient
import NIO
import NIOSSL

extension Mongo
{
    /// @import(NIOCore)
    /// A connection to a mongo host that we have completed an initial handshake with.
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
        init(_ channel:any Channel, instance:Instance)
        {
            self.channel = channel
            self.instance = instance
        }
        func close()
        {
            self.channel.close(mode: .all, promise: nil)
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

    static 
    func connect(to host:Mongo.Host, 
        settings:Mongo.ConnectionSettings, 
        group:any EventLoopGroup,
        dns:DNSClient? = nil) async throws -> Self 
    {
        let unestablished:Mongo.UnestablishedConnection = 
            try await .connect(to: host, settings: settings, group: group, dns: dns)

        do
        {
            let instance:Mongo.Instance = try await unestablished.establish(
                authentication: settings.authentication)
            
            let connection:Self = .init(unestablished.channel, instance: instance)
            if  let authentication:Mongo.ConnectionSettings.Authentication = 
                    settings.authentication,
                let mechanism:Mongo.SASL.Mechanism =
                    authentication.mechanism?.sasl ?? instance.saslSupportedMechs?.first
            {
                try await connection.authenticate(with: authentication, mechanism: mechanism)
            }
            return connection
        }
        catch let error
        {
            try await unestablished.channel.close()
            throw error
        }
    }

    func reestablish(
        authentication:Mongo.ConnectionSettings.Authentication?) async throws -> Self
    {
        let unestablished:Mongo.UnestablishedConnection = .init(channel: self.channel)
        return .init(unestablished.channel, 
            instance: try await unestablished.establish(authentication: authentication))
    }
}

extension Mongo.Connection
{
    /// Runs an authentication command against the specified `database`.
    func run<Command>(command:__owned Command,
        against database:Mongo.Database) async throws -> Mongo.SASL.Response
        where Command:MongoAuthenticationCommand
    {
        try Command.decode(message: try await self.run(command: command,
            against: database,
            session: nil))
    }
    func run(command:__owned some MongoCommand, against database:Mongo.Database,
        transaction:Never? = nil,
        session:Mongo.Session.ID?) async throws -> Mongo.Message<ByteBufferView>
    {
        var command:BSON.Fields<[UInt8]> = command.fields
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
            (continuation:CheckedContinuation<Mongo.Message<ByteBufferView>, any Error>) in
            self.channel.writeAndFlush((command, continuation), promise: nil)
        }
    }
}

extension Mongo.Connection
{
    private
    func authenticate(with authentication:Mongo.ConnectionSettings.Authentication,
        mechanism:Mongo.SASL.Mechanism) async throws 
    {
        switch mechanism 
        {
        case .sha1:
            return try await self.authenticateSASL(mechanism, hasher: SHA1.init(),
                database: authentication.database, 
                username: authentication.username,
                password: authentication.password)
        case .sha256:
            return try await self.authenticateSASL(mechanism, hasher: SHA256(),
                database: authentication.database, 
                username: authentication.username,
                password: authentication.password)
        default:
            fatalError("authentication mechanism \(mechanism) has not been implemented yet")
        }
    }

    /// Handles a SCRAM authentication flow
    ///
    /// The Hasher `H` specifies the hashing algorithm used with SCRAM.
    private
    func authenticateSASL<H:Hash>(_ mechanism:Mongo.SASL.Mechanism, hasher:H, 
        database:Mongo.Database, 
        username:String, 
        password:String) async throws 
    {
        let context = SCRAM<H>(hasher)

        let _request:String = try context.authenticationString(forUser: username)
        let command:Mongo.SASL.Start = .init(mechanism: mechanism, 
            payload: Data.init(_request.utf8).base64EncodedString())

        let challenge:Mongo.SASL.Response = try await self.run(command: command,
            against: database)
        
        if  challenge.done 
        {
            return
        }

        let _response:String = try context.respond(
            toChallenge: try challenge.payload.base64Decoded(),
            password: mechanism.password(hashing: password, username: username))

        let acceptance:Mongo.SASL.Response = try await self.run(
            command: challenge.command(payload: Data.init(_response.utf8).base64EncodedString()),
            against: database)
        
        try context.completeAuthentication(withResponse: try acceptance.payload.base64Decoded())
        
        if  acceptance.done 
        {
            return
        }
        
        let completion:Mongo.SASL.Response = try await self.run(
            command: acceptance.command(payload: ""),
            against: database)
        
        guard completion.done
        else 
        {
            throw MongoAuthenticationError(reason: .malformedAuthenticationDetails)
        }
    }
}
