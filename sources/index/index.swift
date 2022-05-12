@_exported import Biome 
import Bureaucrat
import Resource
import JSON

extension Module 
{
    struct Descriptor:Decodable 
    {
        let id:ID
        let include:[String] 
        let dependencies:[Graph.Dependency]
        
        func load(prefix:FilePath, with load:(FilePath, Resource.Text) async throws -> Resource) 
            async throws -> Catalog
        {
            var locations:
            (
                articles:[(name:String, source:FilePath)],
                colonies:[(namespace:ID, graph:FilePath)],
                core:FilePath?
            )
            locations.articles = []
            locations.colonies = []
            locations.core = nil
            for include:FilePath in self.include.map(FilePath.init(_:))
            {
                let root:FilePath = include.isAbsolute ? include : prefix.appending(include.components)
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
                        locations.articles.append((file.stem, location))
                    
                    case "json"?:
                        guard   let reduced:FilePath.Component = .init(file.stem),
                                case "symbols"? = reduced.extension
                        else 
                        {
                            break 
                        }
                        let identifiers:[Substring] = reduced.stem.split(separator: "@", omittingEmptySubsequences: false)
                        guard case self.id? = identifiers.first.map(ID.init(_:))
                        else 
                        {
                            print("warning: ignored symbolgraph with invalid name '\(reduced.stem)'")
                            break 
                        }
                        switch (identifiers.count, locations.core)
                        {
                        case (1, nil): 
                            locations.core = location
                        case (1, _?):
                            print("warning: ignored duplicate symbolgraph '\(reduced.stem)'")
                        case (2, _):
                            locations.colonies.append((ID.init(identifiers[1]), location))
                        default: 
                            return
                        }
                        
                    default: 
                        break
                    }
                }
            }
            
            let core:Resource
            if let location:FilePath = locations.core 
            {
                core = try await load(location, .json)
            }
            else 
            {
                throw GraphError.missing(id: self.id)
            }
            var colonies:[(ID, Resource)] = []
                colonies.reserveCapacity(locations.colonies.count)
            for (namespace, location):(ID, FilePath) in locations.colonies 
            {
                colonies.append((namespace, try await load(location, .json)))
            }
            var articles:[(String, Resource)] = []
                articles.reserveCapacity(locations.articles.count)
            for (name, location):(String, FilePath) in locations.articles 
            {
                articles.append((name, try await load(location, .markdown)))
            }
            return .init(id: self.id, core: core, colonies: colonies, articles: articles, 
                dependencies: self.dependencies)
        }
    }
}
extension Package 
{
    public 
    struct Descriptor:Decodable 
    {
        let id:ID
        let toolsVersion:Int
        let modules:[Module.Descriptor]
        
        enum CodingKeys:String, CodingKey 
        {
            case id             = "package" 
            case modules        = "modules"
            case toolsVersion   = "catalog_tools_version"
        }
        
        public 
        func load(prefix:FilePath, with loader:(FilePath, Resource.Text) async throws -> Resource) 
            async throws -> Package.Catalog
        {
            guard self.toolsVersion == 2
            else 
            {
                fatalError("version mismatch")
            }
            var modules:[Module.Catalog] = []
            for module:Module.Descriptor in self.modules 
            {
                modules.append(try await module.load(prefix: prefix, with: loader))
            }
            return .init(id: self.id, modules: modules)
        }
    }
    
    public static 
    func descriptors(parsing file:[UInt8]) throws -> [Descriptor]
    {
        try Grammar.parse(file, as: JSON.Rule<Array<UInt8>.Index>.Array.self).map(Descriptor.init(from:))
    }
}

/* extension Biome
{
    
    static 
    func catalogs(parsing file:[UInt8], repository:FilePath) throws -> [Package.Graph]
    {
        try Grammar.parse(file, as: JSON.Rule<Array<UInt8>.Index>.Array.self).map
        {
            .init(loading: try Package.Descriptor.init(from: $0), repository: repository)
        }
    }
    
    public mutating 
    func update(loading path:FilePath) async throws
    {
        try await self.update(loading: CollectionOfOne<FilePath>.init(path))
    }
    public mutating 
    func update<Indices>(loading paths:Indices) async throws
        where Indices:Sequence, Indices.Element == FilePath
    {
        let catalogs:[Package.Catalog<FilePath>] = try paths.flatMap 
        {
            try Self.catalogs(
                parsing: try Bureaucrat.read(from: $0), 
                repository: .init(root: nil))
        }
        try await self.init(serving: channels, template: template, loading: catalogs)
        {
            .utf8(encoded: try Bureaucrat.read(from: $0), type: $1, version: nil)
        }
    }
    public 
    init(serving channels:[Documentation.Channel: String], 
        template:DocumentTemplate<Documentation.Anchor, [UInt8]>, 
        loading path:FilePath, 
        with loader:Bureaucrat) async throws
    {
        try await self.init(serving: channels, template: template, loading: CollectionOfOne<FilePath>.init(path), with: loader)
    }
    public 
    init<Indices>(serving channels:[Documentation.Channel: String], 
        template:DocumentTemplate<Documentation.Anchor, [UInt8]>, 
        loading paths:Indices, 
        with loader:Bureaucrat) async throws
        where Indices:Sequence, Indices.Element == FilePath
    {
        let catalogs:[Catalog<FilePath>] = try paths.flatMap 
        { 
            try Self.catalogs(
                parsing: try Bureaucrat.read(from: loader.repository.appending($0.components)), 
                repository: loader.repository)
        }
        try await self.init(serving: channels, template: template, loading: catalogs, with: loader.read(from:type:))
    }
} */
