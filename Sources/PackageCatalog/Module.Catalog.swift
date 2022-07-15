import Biome 
import SystemExtras
@preconcurrency import SystemPackage

extension Module 
{
    public 
    enum SubgraphLoadingError:Error, CustomStringConvertible 
    {
        case invalidName(String)
        case duplicateSubgraph(ID)
        case missingCoreSubgraph(ID)
        
        public 
        var description:String 
        {
            switch self 
            {
            case .invalidName(let string): 
                return "invalid subgraph name '\(string)'"
            case .duplicateSubgraph(let id): 
                return "duplicate subgraphs for primary culture '\(id)'"
            case .missingCoreSubgraph(let id): 
                return "missing subgraph for primary culture '\(id)'"
            }
        }
    }
    public 
    struct Catalog:Decodable, Sendable 
    {
        public
        let id:ID
        var include:[FilePath] 
        var dependencies:[Graph.Dependency]
        
        public 
        enum CodingKeys:String, CodingKey 
        {
            case id = "module" 
            case include 
            case dependencies
        }
        
        public
        init(from decoder:any Decoder) throws 
        {
            let container:KeyedDecodingContainer<CodingKeys> = 
                try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try container.decode(ID.self, forKey: .id)
            // need to do this manually
            // https://github.com/apple/swift-system/issues/106
            self.include = try container.decode([String].self, 
                forKey: .include).map(FilePath.init(_:))
            self.dependencies = try container.decode([Graph.Dependency].self, 
                forKey: .dependencies)
        }
        
        public 
        init(id:ID, include:[FilePath], dependencies:[Graph.Dependency])
        {
            self.id = id 
            self.include = include 
            self.dependencies = dependencies
        }
        
        func loadGraph(relativeTo prefix:FilePath?) throws -> Graph
        {
            try Task.checkCancellation()
            
            func absolute(_ path:FilePath) -> FilePath 
            {
                path.isAbsolute ? path : prefix?.appending(path.components) ?? path
            }
            
            var paths:
            (
                articles:[(name:String, source:FilePath)],
                colonies:[(namespace:ID, graph:FilePath)],
                core:FilePath?
            )
            paths.articles = []
            paths.colonies = []
            paths.core = nil
            for include:FilePath in self.include
            {
                let include:FilePath = absolute(include)
                try include.walk
                {
                    (path:FilePath) in 
                    
                    guard let file:FilePath.Component = path.components.last 
                    else 
                    {
                        return 
                    }
                    
                    let path:FilePath = include.appending(path.components)
                    
                    switch file.extension
                    {
                    case "md"?:
                        paths.articles.append((file.stem, path))
                    
                    case "json"?:
                        guard   let reduced:FilePath.Component = .init(file.stem),
                                case "symbols"? = reduced.extension
                        else 
                        {
                            break 
                        }
                        let identifiers:[Substring] = reduced.stem.split(separator: "@", 
                            omittingEmptySubsequences: false)
                        guard case self.id? = identifiers.first.map(ID.init(_:))
                        else 
                        {
                            throw SubgraphLoadingError.invalidName(reduced.stem)
                        }
                        switch (identifiers.count, paths.core)
                        {
                        case (1, nil): 
                            paths.core = path
                        case (1, _?):
                            print("warning: ignored duplicate symbolgraph '\(reduced.stem)'")
                        case (2, _):
                            paths.colonies.append((ID.init(identifiers[1]), path))
                        default: 
                            return
                        }
                        
                    default: 
                        break
                    }
                }
            }
            
            guard let core:FilePath = paths.core 
            else 
            {
                throw SubgraphLoadingError.missingCoreSubgraph(self.id)
            }
            return .init(
                core: try .init(parsing: try   core.read([UInt8].self), culture: self.id), 
                colonies: try paths.colonies.map 
                {
                    try .init(parsing: try $0.graph.read([UInt8].self), culture: self.id, 
                        namespace: $0.namespace)
                }, 
                articles: try paths.articles.map 
                {
                    .init(parsing: try $0.source.read(String.self), name: $0.name)
                }, 
                dependencies: self.dependencies)
        }
    }
}
