import BSON
import DNSClient
import NIO
import NIOSSL

extension Mongo
{
    struct UnconfirmedConnection:Sendable
    {
        let channel:any Channel
    }
}
extension Mongo.UnconfirmedConnection
{
    private static 
    func addHandlers(to channel:any Channel) -> EventLoopFuture<Void> 
    {
        channel.pipeline.addHandler(ByteToMessageHandler<MongoServerReplyDecoder>(.init()))
            .flatMap
        {
            channel.pipeline.addHandler(MongoRouter.init())
        }
    }

    static 
    func connect(to host:Mongo.Host, tls:Mongo.ConnectionMetadata.TLS?, 
        on group:any EventLoopGroup,
        resolver:DNSClient? = nil) async throws -> Self 
    {
        let bootstrap:ClientBootstrap = .init(group: group)
            .resolver(resolver)
            .channelOption(ChannelOptions.socket(SocketOptionLevel.init(SOL_SOCKET), SO_REUSEADDR), 
                value: 1)
            .channelInitializer 
            { 
                (channel:any Channel) in

                guard let tls:Mongo.ConnectionMetadata.TLS
                else
                {
                    return Self.addHandlers(to: channel)
                }
                do 
                {
                    var configuration:TLSConfiguration = .clientDefault
                    configuration.trustRoots = NIOSSLTrustRoots.file(tls.certificatePath)
                    
                    let handler:NIOSSLClientHandler = try .init(
                        context: .init(configuration: configuration), 
                        serverHostname: host.name)
                    return channel.pipeline.addHandler(handler).flatMap 
                    {
                        return Self.addHandlers(to: channel)
                    }
                } 
                catch let error
                {
                    return channel.eventLoop.makeFailedFuture(error)
                }
            }
        
        return .init(
            channel: try await bootstrap.connect(host: host.name, port: host.port).get())
    }
}
extension Mongo.UnconfirmedConnection
{
    /// Executes a MongoDB `isMaster`
    ///
    /// - SeeAlso: https://github.com/mongodb/specifications/blob/master/source/mongodb-handshake/handshake.rst
    func confirm(authenticationDatabase:String, 
        credentials:Mongo.Authentication) async throws -> ServerHandshake 
    {
        let userNamespace: String?
        if case .auto(let user, _) = credentials 
        {
            userNamespace = "\(authenticationDatabase).\(user)"
        } 
        else 
        {
            userNamespace = nil
        }
        
        // NO session must be used here: 
        // https://github.com/mongodb/specifications/blob/master/source/sessions/driver-sessions.rst#when-opening-and-authenticating-a-connection
        let isMaster:Mongo.IsMaster = .init(userNamespace: userNamespace)
        var command:Document = isMaster.bson
            command.appendValue("admin", forKey: "$db")
        
        let reply:OpMessage = try await withCheckedThrowingContinuation
        {
            (continuation:CheckedContinuation<OpMessage, Error>) in
            self.channel.writeAndFlush((command, continuation), promise: nil)
        }
        guard let document:Document = reply.first
        else
        {
            throw MongoCommandError.emptyReply
        }

        return try BSONDecoder().decode(ServerHandshake.self, from: document)
    }
}