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
    @Option(name: [.customShort("b"), .customLong("resources")], help: "path to a copy of the 'swift-biome-resources' repository")
    var resources:String = ".biome/resources"
    
    @Argument(help: "path(s) to documentation index file")
    var indices:[String] 
    
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
        let indices:[[Package.Descriptor]] = try self.indices.map
        {
            try Package.descriptors(parsing: try Bureaucrat.read(from: FilePath.init($0)))
        }
        let resources:[String: Resource] = 
        [
            "/biome.css"        : try await bureaucrat.read(concatenating: "default-dark/common.css", "default-dark/biome.css", type: .css), 
            "/search.js"        : try await bureaucrat.read(concatenating: "lunr.js", "search.js", type: .javascript), 
            
            "/text-45.ttf"      : try await bureaucrat.read(from: "fonts/literata/Literata-Regular.ttf",          type: .ttf), 
            "/text-47.ttf"      : try await bureaucrat.read(from: "fonts/literata/Literata-RegularItalic.ttf",    type: .ttf), 
            "/text-65.ttf"      : try await bureaucrat.read(from: "fonts/literata/Literata-SemiBold.ttf",         type: .ttf), 
            "/text-67.ttf"      : try await bureaucrat.read(from: "fonts/literata/Literata-SemiBoldItalic.ttf",   type: .ttf), 
            
            "/text-45.woff2"    : try await bureaucrat.read(from: "fonts/literata/Literata-Regular.woff2",        type: .woff2), 
            "/text-47.woff2"    : try await bureaucrat.read(from: "fonts/literata/Literata-RegularItalic.woff2",  type: .woff2), 
            "/text-65.woff2"    : try await bureaucrat.read(from: "fonts/literata/Literata-SemiBold.woff2",       type: .woff2), 
            "/text-67.woff2"    : try await bureaucrat.read(from: "fonts/literata/Literata-SemiBoldItalic.woff2", type: .woff2), 
        ]
        
        let preview:Preview = try await .init(indices.joined(), resources: _move(resources))
        
        let host:String = self.host 
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
    var biome:Biome
    
    init<S>(_ descriptors:S, resources:[String: Resource]) async throws 
        where S:Sequence, S.Element == Package.Descriptor
    {
        self.resources = resources
        self.biome = .init(channels: [.symbol: "/reference", .article: "/learn"], 
            template: .init(freezing: DefaultTemplates.documentation))
        for descriptor:Package.Descriptor in descriptors 
        {
            let catalog:Package.Catalog = try await descriptor.load(prefix: .init(root: nil))
            {
                .utf8(encoded: try Bureaucrat.read(from: $0), type: $1, version: nil)
            }
            try self.biome.append(try catalog.graph())
        }
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
        else if let response:StaticResponse = self.biome[uri, referrer: nil]
        {
            
            return .immediate(response)
        }
        else 
        {
            return .immediate(.none(.text("page not found")))
        }
    }
}
