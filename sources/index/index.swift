@_exported import Biome 
import StructuredDocument
import Bureaucrat
import JSON

extension Documentation.Catalog where Location == FilePath 
{
    init(loading descriptor:Documentation.CatalogDescriptor, repository:FilePath)
    {
        let package:Biome.Package.ID
        switch descriptor.package 
        {
        case "swift-standard-library", "swift-stdlib", "swift", 
                   "standard-library",       "stdlib",      "":
            package = .swift 
        case let name:
            package = .community(name)
        }
        var articles:[Article] = []
        var graphs:[Substring: [Module.Graph]] = [:]
        for include:FilePath in descriptor.include.map(FilePath.init(_:))
        {
            let root:FilePath = include.isAbsolute ? include : repository.appending(include.components)
            root.walk
            {
                (path:FilePath) in 
                
                guard let file:FilePath.Component = path.components.last 
                else 
                {
                    return 
                }
                let location:FilePath = include.appending(path.components)
                switch file.extension
                {
                case "md"?:
                    var path:[String] = path.components.dropLast().map(\.string)
                        path.append(file.stem)
                    articles.append(.init(path: path, location: location))
                case "json"?:
                    
                    guard   let reduced:FilePath.Component = .init(file.stem),
                            case "symbols"? = reduced.extension
                    else 
                    {
                        break 
                    }
                    let identifiers:[Substring] = reduced.stem.split(separator: "@", omittingEmptySubsequences: false)
                    guard   let first:Substring = identifiers.first, 
                            let last:Substring  = identifiers.last, identifiers.count <= 2 
                    else 
                    {
                        print("warning: ignored symbolgraph with invalid name '\(reduced.stem)'")
                        break 
                    }
                    graphs[first, default: []]
                        .append(.init(namespace: Biome.Module.ID.init(last), location: location))
                    
                default: 
                    break
                }
            }
        }
        let modules:[Module] = descriptor.modules.compactMap 
        {
            let module:Biome.Module.ID = .init($0)
            
            var core:Module.Graph? = nil 
            var bystanders:[Module.Graph] = []
            for graph:Module.Graph in graphs[$0[...], default: []]
            {
                guard graph.namespace != module 
                else 
                {
                    if case nil = core
                    {
                        core = graph
                    }
                    else 
                    {
                        print("warning: ignored duplicate symbolgraph '\(graph.namespace.string)'")
                    }
                    continue 
                }
                bystanders.append(graph)
            }
            guard let core:Module.Graph = core 
            else 
            {
                print("warning: skipped module '\(module.string)' because its core symbolgraph is missing")
                return nil
            }
            return .init(core: core, bystanders: bystanders.sorted { $0.namespace.string < $1.namespace.string })
        }
        self.init(format: descriptor.format, package: package, articles: articles, modules: modules)
    }
}
extension Documentation 
{
    struct CatalogDescriptor:Decodable 
    {
        let format:Format
        let package:String
        let include:[String]
        let modules:[String]
    }
    
    static 
    func catalogs(parsing file:[UInt8], repository:FilePath) throws -> [Catalog<FilePath>]
    {
        let descriptors:[JSON] = try Grammar.parse(file, as: JSON.Rule<Array<UInt8>.Index>.Array.self)
        return try descriptors.map
        {
            Catalog<FilePath>.init(loading: try CatalogDescriptor.init(from: $0), repository: repository)
        }
    }
    
    public 
    init(serving bases:[URI.Base: String], 
        template:DocumentTemplate<Anchor, [UInt8]>, 
        loading path:FilePath) async throws
    {
        try await self.init(serving: bases, template: template, loading: CollectionOfOne<FilePath>.init(path))
    }
    public 
    init<Indices>(serving bases:[URI.Base: String], 
        template:DocumentTemplate<Anchor, [UInt8]>, 
        loading paths:Indices) async throws
        where Indices:Sequence, Indices.Element == FilePath
    {
        let catalogs:[Catalog<FilePath>] = try paths.flatMap 
        {
            try Self.catalogs(parsing: try Bureaucrat.read(from: $0), repository: .init(root: nil))
        }
        try await self.init(serving: bases, template: template, loading: catalogs)
        {
            .utf8(encoded: try Bureaucrat.read(from: $0), type: $1, version: nil)
        }
    }
    public 
    init(serving bases:[URI.Base: String], 
        template:DocumentTemplate<Anchor, [UInt8]>, 
        loading path:FilePath, 
        with loader:Bureaucrat) async throws
    {
        try await self.init(serving: bases, template: template, loading: CollectionOfOne<FilePath>.init(path), with: loader)
    }
    public 
    init<Indices>(serving bases:[URI.Base: String], 
        template:DocumentTemplate<Anchor, [UInt8]>, 
        loading paths:Indices, 
        with loader:Bureaucrat) async throws
        where Indices:Sequence, Indices.Element == FilePath
    {
        let catalogs:[Catalog<FilePath>] = try paths.flatMap 
        { 
            try Self.catalogs(parsing: try Bureaucrat.read(from: loader.repository.appending($0.components)), 
                repository: loader.repository)
        }
        try await self.init(serving: bases, template: template, loading: catalogs, with: loader.read(from:type:))
    }
}
