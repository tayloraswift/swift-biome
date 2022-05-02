@_exported import Biome 
import StructuredDocument
import Bureaucrat
import JSON

struct ModuleDescriptor:Decodable 
{
    let id:Module.ID
    let include:[String] 
    let dependencies:[_Graph.Dependency]
}
struct PackageDescriptor:Decodable 
{
    let package:Package.ID
    let toolsVersion:Int
    let modules:[ModuleDescriptor]
    
    enum CodingKeys:String, CodingKey 
    {
        case package 
        case modules
        case toolsVersion = "catalog_tools_version"
    }
}

extension Module.Catalog where Location == FilePath 
{
    init?(loading descriptor:ModuleDescriptor, repository:FilePath)
    {
        self.id = descriptor.id
        self.dependencies = descriptor.dependencies
        
        var articles:[(name:String, source:FilePath)] = []
        var bystanders:[(namespace:Module.ID, graph:FilePath)] = []
        var core:FilePath? = nil
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
                    articles.append((file.stem, location))
                
                case "json"?:
                    guard   let reduced:FilePath.Component = .init(file.stem),
                            case "symbols"? = reduced.extension
                    else 
                    {
                        break 
                    }
                    let identifiers:[Substring] = reduced.stem.split(separator: "@", omittingEmptySubsequences: false)
                    guard case self.id? = identifiers.first.map(Module.ID.init(_:))
                    else 
                    {
                        print("warning: ignored symbolgraph with invalid name '\(reduced.stem)'")
                        break 
                    }
                    switch (identifiers.count, core)
                    {
                    case (1, nil): 
                        core = location
                    case (1, _?):
                        print("warning: ignored duplicate symbolgraph '\(reduced.stem)'")
                    case (2, _):
                        bystanders.append((Module.ID.init(identifiers[1]), location))
                    }
                    
                default: 
                    break
                }
            }
        }
        guard let core:FilePath = core 
        else 
        {
            print("warning: skipped module '\(self.id)' because its core symbolgraph is missing")
            return nil 
        }
        self.graphs = (core, bystanders) 
        self.articles = articles 
    }
}
extension Package.Catalog where Location == FilePath 
{
    init(loading descriptor:PackageDescriptor, repository:FilePath)
    {
        guard descriptor.toolsVersion == 2
        else 
        {
            fatalError("version mismatch")
        }
        self.id = descriptor.id
        self.modules = descriptor.modules.compactMap { .init(loading: $0, repository: repository) }
    }
}
extension Package 
{
    static 
    func catalogs(parsing file:[UInt8], repository:FilePath) throws -> [Catalog<FilePath>]
    {
        let descriptors:[JSON] = try Grammar.parse(file, as: JSON.Rule<Array<UInt8>.Index>.Array.self)
        return try descriptors.map
        {
            Catalog<FilePath>.init(loading: try CatalogDescriptor.init(from: $0), repository: repository)
        }
    }
}
extension Documentation
{
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
            try Package.catalogs(parsing: try Bureaucrat.read(from: $0), repository: .init(root: nil))
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
            try Package.catalogs(parsing: try Bureaucrat.read(from: loader.repository.appending($0.components)), 
                repository: loader.repository)
        }
        try await self.init(serving: bases, template: template, loading: catalogs, with: loader.read(from:type:))
    }
}
