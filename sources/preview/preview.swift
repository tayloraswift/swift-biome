import ArgumentParser
import SystemPackage
import Backtrace
import Bureaucrat
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
    
    @Option(name: [.customShort("g"), .customLong("git")], help: "path to `git`, if different from '/usr/bin/git'")
    var git:String = "/usr/bin/git"
    @Option(name: [.customShort("x"), .customLong("index")], help: "path to documentation index file")
    var index:String 
    @Option(name: [.customShort("b"), .customLong("resources")], help: "path to a copy of the 'swift-biome-resources' repository")
    var resources:String 
    
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
        
        let bureaucrat:Bureaucrat = .init(git: .init(self.git), repository: .init(self.resources))
        let resources:[String: Resource] = 
        [
            "/biome.css"        : try await bureaucrat.read(concatenating: "default-dark/biome.css", "default-dark/common.css", type: .css), 
            "/search.js"        : try await bureaucrat.read(concatenating: "search.js", "lunr.js", type: .javascript), 
            
            "/text-45.ttf"      : try await bureaucrat.read(from: "fonts/literata/Literata-Regular.ttf",          type: .ttf), 
            "/text-47.ttf"      : try await bureaucrat.read(from: "fonts/literata/Literata-RegularItalic.ttf",    type: .ttf), 
            "/text-65.ttf"      : try await bureaucrat.read(from: "fonts/literata/Literata-SemiBold.ttf",         type: .ttf), 
            "/text-67.ttf"      : try await bureaucrat.read(from: "fonts/literata/Literata-SemiBoldItalic.ttf",   type: .ttf), 
            
            "/text-45.woff2"    : try await bureaucrat.read(from: "fonts/literata/Literata-Regular.woff2",        type: .woff2), 
            "/text-47.woff2"    : try await bureaucrat.read(from: "fonts/literata/Literata-RegularItalic.woff2",  type: .woff2), 
            "/text-65.woff2"    : try await bureaucrat.read(from: "fonts/literata/Literata-SemiBold.woff2",       type: .woff2), 
            "/text-67.woff2"    : try await bureaucrat.read(from: "fonts/literata/Literata-SemiBoldItalic.woff2", type: .woff2), 
        ]
        let documentation:Documentation = try await .init(serving: 
            [
                .biome: "/reference",
                .learn: "/learn",
            ], 
            template: .init(freezing: DefaultTemplates.documentation), 
            indexfile: FilePath.init(self.index))
        
        let host:String = self.host 
        let preview:Preview = .init(documentation: _move(documentation), resources: _move(resources))
        
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
    
    let resources:[String: Resource]
    let documentation:Documentation
    
    init(documentation:Documentation, resources:[String: Resource]) 
    {
        self.documentation = documentation
        self.resources = resources
    }
    
    func request(_:Never, continuation _:EventLoopPromise<StaticResponse>) 
    {
    }
    func request(_ uri:String) -> DynamicResponse<Never> 
    {
        if let resource:Resource = self.resources[uri]
        {
            return .immediate(.matched(canonical: uri, resource))
        }
        else if let response:StaticResponse = self.documentation[uri, referrer: nil]
        {
            
            return .immediate(response)
        }
        else 
        {
            return .immediate(.none(.text("page not found")))
        }
    }
}
