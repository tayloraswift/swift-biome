import ArgumentParser
import Backtrace

import VersionControl
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
    var resources:String = "resources"
    
    @Argument(help: "path(s) to project repositories")
    var projects:[String] 
    
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
        
        let preview:Preview = try await .init(projects: self.projects.map(FilePath.init(_:)), 
            controller: .init(git: .init(self.git), repository: .init(self.resources)))
        
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

extension VersionController 
{
    func read(package:Package.ID) throws -> Package.Descriptor
    {
        let modules:[Module.ID] = try self.read(from: FilePath.init("\(package.string).txt"))
            .split(whereSeparator: \.isWhitespace)
            .map(Module.ID.init(_:))
        return .init(id: package, modules: modules.map 
        {
            // use a relative path, since this is from a git repository. 
            .init(id: $0, include: ["\(package.string)/\($0.string)"], dependencies: [])
        })
    }
}
struct Preview:ServiceBackend 
{
    typealias Continuation = EventLoopPromise<StaticResponse>
    
    let resources:[String: Resource]
    var biome:Biome
    
    init(projects:[FilePath], controller:VersionController) async throws 
    {
        let pins:[Package.ID: Version] = 
        [
            .swift: .tag(5, (7, nil)),
            .core:  .tag(5, (7, nil)),
        ]
        // load the names of the swift standard library modules. 
        let library:(standard:Package.Descriptor, core:Package.Descriptor) = 
        (
            standard:   try controller.read(package: .swift),
            core:       try controller.read(package: .core)
        )
        self.biome = .init(channels: [.symbol: "/reference", .article: "/learn"], 
            standardModules: library.standard.modules.map(\.id), 
            coreModules: library.core.modules.map(\.id), 
            template: .init(freezing: DefaultTemplates.documentation))
        // load the standard and core libraries
        try self.biome.append(try await library.standard.load(with: controller).graph(), pins: pins)
        try self.biome.append(try await     library.core.load(with: controller).graph(), pins: pins)
        
        for project:FilePath in projects 
        {
            let packages:[Package.Descriptor] = try Package.descriptors(parsing: 
                try File.read(from: project.appending("Package.catalog")))
            let resolved:Package.Resolved = try .init(parsing: 
                try File.read(from: project.appending("Package.resolved")))
            for package:Package.Descriptor in packages 
            {
                // user-specified catalogs should contain absolute paths (since that is 
                // what `swift package catalog` emits), and this preview tool does not 
                // support intelligent caching for user-specified package documentation. 
                // so we do not load them through the version controller
                let catalog:Package.Catalog = try await package.load(with: nil), 
                    graph:Package.Graph = try catalog.graph()
                
                try self.biome.append(graph, pins: resolved.pins)
            }
        }
        
        self.resources = 
        [
            "/biome.css"        : try await controller.read(concatenating: "default-dark/common.css", "default-dark/biome.css", type: .css), 
            "/search.js"        : try await controller.read(concatenating: "lunr.js", "search.js", type: .javascript), 
            
            "/text-45.ttf"      : try await controller.read(from: "fonts/literata/Literata-Regular.ttf",          type: .ttf), 
            "/text-47.ttf"      : try await controller.read(from: "fonts/literata/Literata-RegularItalic.ttf",    type: .ttf), 
            "/text-65.ttf"      : try await controller.read(from: "fonts/literata/Literata-SemiBold.ttf",         type: .ttf), 
            "/text-67.ttf"      : try await controller.read(from: "fonts/literata/Literata-SemiBoldItalic.ttf",   type: .ttf), 
            
            "/text-45.woff2"    : try await controller.read(from: "fonts/literata/Literata-Regular.woff2",        type: .woff2), 
            "/text-47.woff2"    : try await controller.read(from: "fonts/literata/Literata-RegularItalic.woff2",  type: .woff2), 
            "/text-65.woff2"    : try await controller.read(from: "fonts/literata/Literata-SemiBold.woff2",       type: .woff2), 
            "/text-67.woff2"    : try await controller.read(from: "fonts/literata/Literata-SemiBoldItalic.woff2", type: .woff2), 
        ]
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
