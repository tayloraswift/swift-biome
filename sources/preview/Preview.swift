import VersionControl
import HTML
import NIO

import BiomeIndex
import BiomeTemplates

extension VersionController 
{
    fileprivate
    func loadSwiftToolchainDirectories(from path:FilePath) 
        throws -> [Substring]
    {
        try self.read(from: path).split(whereSeparator: \.isWhitespace)
    }
    fileprivate
    func loadSwiftToolchainDescriptor(_ package:Package.ID, from directory:FilePath) 
        throws -> Package.Descriptor
    {
        let modules:[Module.ID] = try self.read(from: directory.appending(package.string))
            .split(whereSeparator: \.isWhitespace)
            .map(Module.ID.init(_:))
        return .init(id: package, modules: modules.map 
        {
            // use a relative path, since this is from a git repository. 
            .init(id: $0, include: [directory.appending($0.string).description], dependencies: [])
        })
    }
}
struct Preview:ServiceBackend 
{
    typealias Continuation = EventLoopPromise<StaticResponse>
    
    let resources:[String: Resource]
    var biome:Biome
    
    init(projects:[FilePath], controller:VersionController) 
        async throws 
    {
        self.resources = 
        [
            "/search.js"        : try await controller.read(concatenating: ["lunr.js", "search.js"], type: .javascript), 
            "/biome.css"        : try await controller.read(from: "css/biome.css", type: .css), 
            
            "/text-45.ttf"      : try await controller.read(from: "fonts/literata/Literata-Regular.ttf",          type: .ttf), 
            "/text-47.ttf"      : try await controller.read(from: "fonts/literata/Literata-RegularItalic.ttf",    type: .ttf), 
            "/text-65.ttf"      : try await controller.read(from: "fonts/literata/Literata-SemiBold.ttf",         type: .ttf), 
            "/text-67.ttf"      : try await controller.read(from: "fonts/literata/Literata-SemiBoldItalic.ttf",   type: .ttf), 
            
            "/text-45.woff2"    : try await controller.read(from: "fonts/literata/Literata-Regular.woff2",        type: .woff2), 
            "/text-47.woff2"    : try await controller.read(from: "fonts/literata/Literata-RegularItalic.woff2",  type: .woff2), 
            "/text-65.woff2"    : try await controller.read(from: "fonts/literata/Literata-SemiBold.woff2",       type: .woff2), 
            "/text-67.woff2"    : try await controller.read(from: "fonts/literata/Literata-SemiBoldItalic.woff2", type: .woff2), 
        ]
        self.biome = .init(roots: [.master: "reference", .article: "learn"], 
            template: .init(freezing: DefaultTemplates.documentation))
        
        var pins:[Package.ID: MaskedVersion] = [:]
        // load standard library
        for directory:Substring in try controller.loadSwiftToolchainDirectories(
            from: .init(root: nil, components: "swift", "swift-versions"))
        {
            guard   let version:MaskedVersion = .init(directory), 
                    let component:FilePath.Component = .init(String.init(directory))
            else 
            {
                continue 
            }
            let directory:FilePath = .init(root: nil, components: "swift", component)
            // load the names of the swift standard library modules. 
            let standardLibrary:Package.Descriptor = 
                try controller.loadSwiftToolchainDescriptor(.swift, from: directory)
            let coreLibraries:Package.Descriptor = 
                try controller.loadSwiftToolchainDescriptor(.core, from: directory)
            
            pins = [.swift: version, .core: version]
            
            try self.biome.updatePackage(
                try await standardLibrary.loadGraph(with: controller), era: pins)
            try self.biome.updatePackage(
                try await   coreLibraries.loadGraph(with: controller), era: pins)
        }
        
        for project:FilePath in projects 
        {
            let resolved:Package.Resolved = try .init(parsing: 
                try File.read(from: project.appending("Package.resolved")))
            let packages:[Package.Descriptor] = try Package.descriptors(parsing: 
                try File.read(from: project.appending("Package.catalog")))
            let pins:[Package.ID: MaskedVersion] = pins.merging(resolved.pins) { $1 }
            for package:Package.Descriptor in packages 
            {
                // user-specified catalogs should contain absolute paths (since that is 
                // what `swift package catalog` emits), and this preview tool does not 
                // support intelligent caching for user-specified package documentation. 
                // so we do not load them through the version controller
                try self.biome.updatePackage(try await package.loadGraph(), era: pins)
            }
        }
        
        self.biome.regenerateCaches()
    }
    
    func request(_:Never, continuation _:EventLoopPromise<StaticResponse>) 
    {
    }
    func request(_ uri:String) -> DynamicResponse<Never> 
    {
        if      let resource:Resource = self.resources[uri]
        {
            return .immediate(.matched(resource, canonical: uri))
        }
        else if let uri:URI = try? .init(absolute: uri), 
                let response:StaticResponse = self.biome[uri: uri]
        {
            
            return .immediate(response)
        }
        else 
        {
            return .immediate(.none(.text("page not found")))
        }
    }
}
