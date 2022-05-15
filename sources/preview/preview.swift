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
    
    @Argument(help: "path(s) to documentation index file")
    var catalogs:[String] 
    
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
        
        let catalogs:[[Package.Descriptor]] = try self.catalogs.map
        {
            try Package.descriptors(parsing: try File.read(from: FilePath.init($0)))
        }
        
        let preview:Preview = try await .init(catalogs.joined(), 
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

struct Preview:ServiceBackend 
{
    typealias Continuation = EventLoopPromise<StaticResponse>
    
    let resources:[String: Resource]
    var biome:Biome
    
    init<S>(_ catalogs:S, controller:VersionController) async throws 
        where S:Sequence, S.Element == Package.Descriptor
    {
        // load the names of the swift standard library modules. 
        let standardModules:[Module.ID] = try controller.read(from: "swift.txt")
            .split(whereSeparator: \.isWhitespace)
            .map(Module.ID.init(_:))
        
        self.biome = .init(channels: [.symbol: "/reference", .article: "/learn"], 
            template: .init(freezing: DefaultTemplates.documentation))
        // load the standard library 
        let standardLibrary:Package.Descriptor = .init(id: .swift, 
            modules: standardModules.map 
        {
            (id:Module.ID) in 
            // use a relative path, since this is from a git repository. 
            .init(id: id, include: ["swift/\(id.string)"], dependencies: 
            [
                // every standard library module depends on every other standard 
                // library module, except itself.
                .init(package: .swift, modules: standardModules.filter { $0 != id })
            ])
        })
        try self.biome.append(try await standardLibrary.load(with: controller).graph())
        
        // user-specified catalogs should contain absolute paths (since that is 
        // what `swift package catalog` emits), and this preview tool does not 
        // support intelligent caching for user-specified package documentation. 
        // so we do not load them through the version controller
        for catalog:Package.Descriptor in catalogs 
        {
            try self.biome.append(try await catalog.load(with: nil).graph())
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
