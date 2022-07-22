import SymbolGraphs 
import SystemExtras
@preconcurrency import SystemPackage

public 
enum SymbolGraphLoadingError:Error, CustomStringConvertible 
{
    case invalidName(String)
    case duplicateSubgraph(ModuleIdentifier)
    case missingCoreSubgraph(ModuleIdentifier)
    
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
struct ModuleCatalog:Identifiable, Decodable, Sendable 
{
    public
    let id:ModuleIdentifier
    var include:[FilePath] 
    var dependencies:[ModuleGraph.Dependency]
    
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
        self.dependencies = try container.decode([ModuleGraph.Dependency].self, 
            forKey: .dependencies)
    }
    
    public 
    init(id:ID, include:[FilePath], dependencies:[ModuleGraph.Dependency])
    {
        self.id = id 
        self.include = include 
        self.dependencies = dependencies
    }
    
    func loadGraph(relativeTo prefix:FilePath?) throws -> ModuleGraph
    {
        try Task.checkCancellation()
        
        func absolute(_ path:FilePath) -> FilePath 
        {
            path.isAbsolute ? path : prefix?.appending(path.components) ?? path
        }
        
        var paths:
        (
            extensions:[(name:String, source:FilePath)],
            colonies:[(namespace:ID, graph:FilePath)],
            core:FilePath?
        )
        paths.extensions = []
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
                    paths.extensions.append((file.stem, path))
                
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
                        throw SymbolGraphLoadingError.invalidName(reduced.stem)
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
            throw SymbolGraphLoadingError.missingCoreSubgraph(self.id)
        }
        return .init(
            core: try .init(parsing: try   core.read([UInt8].self), culture: self.id), 
            colonies: try paths.colonies.map 
            {
                try .init(parsing: try $0.graph.read([UInt8].self), culture: self.id, 
                    namespace: $0.namespace)
            }, 
            extensions: try paths.extensions.map 
            {
                (name: $0.name, source: try $0.source.read(String.self))
            }, 
            dependencies: self.dependencies)
    }
}
