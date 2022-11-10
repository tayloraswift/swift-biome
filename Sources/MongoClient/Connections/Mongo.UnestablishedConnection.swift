import BSONEncoding
import DNSClient
import NIO
import NIOSSL

extension Mongo.ConnectionSettings
{
    fileprivate
    func addHandlers(to channel:any Channel) -> EventLoopFuture<Void> 
    {
        channel.pipeline.addHandler(ByteToMessageHandler<Mongo.MessageDecoder>(.init()))
            .flatMap
        {
            channel.pipeline.addHandler(Mongo.MessageRouter.init(timeout: self.queryTimeout))
        }
    }
}
extension Mongo
{
    struct UnestablishedConnection:Sendable
    {
        let channel:any Channel
    }
}
extension Mongo.UnestablishedConnection
{

    static 
    func connect(to host:Mongo.Host, settings:Mongo.ConnectionSettings, 
        group:any EventLoopGroup,
        dns:DNSClient? = nil) async throws -> Self 
    {
        let bootstrap:ClientBootstrap = .init(group: group)
            .resolver(dns)
            .channelOption(ChannelOptions.socket(SocketOptionLevel.init(SOL_SOCKET), SO_REUSEADDR), 
                value: 1)
            .channelInitializer 
            { 
                (channel:any Channel) in

                guard let tls:Mongo.ConnectionSettings.TLS = settings.tls
                else
                {
                    return settings.addHandlers(to: channel)
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
                        return settings.addHandlers(to: channel)
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
extension Mongo.UnestablishedConnection
{
    /// Executes a MongoDB `isMaster`
    ///
    /// - SeeAlso: https://github.com/mongodb/specifications/blob/master/source/mongodb-handshake/handshake.rst
    func establish(authentication:Mongo.ConnectionSettings.Authentication?) 
        async throws -> Mongo.Instance
    {
        // NO session must be used here: 
        // https://github.com/mongodb/specifications/blob/master/source/sessions/driver-sessions.rst#when-opening-and-authenticating-a-connection
        let hello:Mongo.Hello = .init(user: authentication?.user)
        var command:BSON.Fields<[UInt8]> = hello.fields
            command.add(database: .admin)
        let message:Mongo.Message<ByteBufferView> = try await withCheckedThrowingContinuation
        {
            (continuation:CheckedContinuation<Mongo.Message<ByteBufferView>, any Error>) in
            self.channel.writeAndFlush((command, continuation), promise: nil)
        }
        return try Mongo.Hello.decode(message: message)
    }
}
