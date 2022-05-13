@_exported import Biome 
import VersionControl
import JSON

extension Package 
{
    public 
    struct Descriptor:Decodable 
    {
        public
        enum CodingKeys:String, CodingKey 
        {
            case id             = "package" 
            case modules        = "modules"
            case toolsVersion   = "catalog_tools_version"
        }
        
        let id:ID
        let modules:[Module.Descriptor]
        let toolsVersion:Int
        
        static 
        let toolsVersion:Int = 2
        
        public 
        init(id:ID, modules:[Module.Descriptor])
        {
            self.id = id 
            self.modules = modules
            self.toolsVersion = Self.toolsVersion
        }
        
        public 
        func load(with controller:VersionController?) 
            async throws -> Package.Catalog
        {
            guard self.toolsVersion == Self.toolsVersion
            else 
            {
                fatalError("version mismatch")
            }
            var modules:[Module.Catalog] = []
            for module:Module.Descriptor in self.modules 
            {
                modules.append(try await module.load(with: controller))
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
extension Module 
{
    public 
    struct Descriptor:Decodable 
    {
        let id:ID
        let include:[String] 
        let dependencies:[Graph.Dependency]
        
        public 
        enum CodingKeys:String, CodingKey 
        {
            case id = "module" 
            case include 
            case dependencies
        }
        
        public 
        init(id:ID, include:[String], dependencies:[Graph.Dependency])
        {
            self.id = id 
            self.include = include 
            self.dependencies = dependencies
        }
        
        func load(with controller:VersionController? = nil) async throws -> Catalog
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
                // if the include path is relative, and we are using a version controller, 
                // prepend the repository base to the path.
                let root:FilePath 
                if let prefix:FilePath = controller?.repository 
                {
                    root = include.isAbsolute ? include : prefix.appending(include.components)
                }
                else 
                {
                    root = include
                }
                
                root.walk
                {
                    (path:FilePath) in 
                    
                    guard let file:FilePath.Component = path.components.last 
                    else 
                    {
                        return 
                    }
                    // this is *relative* if `include` was relative
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
            
            func load(_ path:FilePath, _ type:Resource.Text) async throws -> Resource 
            {
                try await controller?.read(from: path, type: type) ?? .utf8(encoded: File.read(from: path), type: type)
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
