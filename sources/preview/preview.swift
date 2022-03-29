import ArgumentParser
import SystemPackage
import Backtrace
import Resource
import NIO

import BiomeIndex
import BiomeTemplates

@main 
struct Main:AsyncParsableCommand 
{
    static 
    var configuration:CommandConfiguration = .init(abstract: "preview swift-biome documentation")
        
    @Option(name: [.customShort("i"), .customLong("ip")], help: "private address to listen on")
    var ip:String = "0.0.0.0" 
    @Option(name: [.customLong("host")], help: "host address")
    var host:String = "127.0.0.1" 
    
    @Option(name: [.customShort("x"), .customLong("index")], help: "documentation index")
    var index:String 
    
    static 
    func main() async 
    {
        do 
        {
            let command:Self = try Self.parseAsRoot() as! Self
            try await command.run()
        } 
        catch 
        {
            exit(withError: error)
        }
    }
    
    func run() async throws 
    {
        Backtrace.install()
        
        let documentation:Documentation = try await .init(serving: 
            [
                .biome: "/reference",
                .learn: "/learn",
            ], 
            template: .init(freezing: DefaultTemplates.documentation), 
            indexfile: FilePath.init(self.index))
        
        let host:String = self.host 
        let preview:Preview = try .init(host: host, documentation: _move(documentation))
        
        let group:MultiThreadedEventLoopGroup   = .init(numberOfThreads: 4)
        let bootstrap:ServerBootstrap           = .init(group: group)
            .serverChannelOption(ChannelOptions.backlog,                        value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr),    value:   1)
            .childChannelInitializer 
        { 
            (channel:Channel) -> EventLoopFuture<Void> in
            
            return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap 
            {
                channel.pipeline.addHandler(Endpoint<Preview>.init(backend: preview, host: host))
            }
        }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr),     value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead,              value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure,          value: true)

        let stopped:EventLoopFuture<Void> = bootstrap.bind(host: self.ip, port: 8080)
            .flatMap(\.closeFuture)
        try await stopped.get()
    }
}

struct Preview:ServiceBackend 
{
    typealias Continuation = EventLoopPromise<StaticResponse>
    
    let documentation:Documentation
    
    init(host _:String, documentation:Documentation) 
    {
        self.documentation = documentation
    }
    
    func request(_:Never, continuation _:EventLoopPromise<StaticResponse>) 
    {
    }
    func request(_ uri:String) -> DynamicResponse<Never> 
    {
        .immediate(self.documentation[uri, referrer: nil] ?? .none(.text("page not found")))
    }
}