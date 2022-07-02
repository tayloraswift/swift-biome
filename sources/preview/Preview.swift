import VersionControl
import HTML
import NIO

import BiomeIndex
import BiomeTemplates

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
        let pins:[Package.ID: MaskedVersion] = 
        [
            .swift: .minor(5, 7),
            .core:  .minor(5, 7),
        ]
        // load the names of the swift standard library modules. 
        let library:(standard:Package.Descriptor, core:Package.Descriptor) = 
        (
            standard:   try controller.read(package: .swift),
            core:       try controller.read(package: .core)
        )
        let template:DOM.Template<Page.Key, [UInt8]> = 
            .init(freezing: DefaultTemplates.documentation)
        self.biome = .init(roots: [.master: "reference", .article: "learn"], 
            template: template)
        // load the standard and core libraries
        try self.biome.updatePackage(try await library.standard.load(with: controller).graph(), era: pins)
        try self.biome.updatePackage(try await     library.core.load(with: controller).graph(), era: pins)
        
        for project:FilePath in projects 
        {
            let packages:[Package.Descriptor] = try Package.descriptors(parsing: 
                try File.read(from: project.appending("Package.catalog")))
            let resolved:Package.Resolved = try .init(parsing: 
                try File.read(from: project.appending("Package.resolved")))
            let pins:[Package.ID: MaskedVersion] = pins.merging(resolved.pins) { $1 }
            for package:Package.Descriptor in packages 
            {
                // user-specified catalogs should contain absolute paths (since that is 
                // what `swift package catalog` emits), and this preview tool does not 
                // support intelligent caching for user-specified package documentation. 
                // so we do not load them through the version controller
                let catalog:Package.Catalog = try await package.load(with: nil), 
                    graph:Package.Graph = try catalog.graph()
                
                try self.biome.updatePackage(graph, era: pins)
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
