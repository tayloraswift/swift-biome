import Biome 
import VersionControl

extension Module 
{
    public 
    struct Descriptor:Decodable, Sendable 
    {
        public
        let id:ID
        var include:[String] 
        var dependencies:[Graph.Dependency]
        
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
            try Task.checkCancellation()
            
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
