import SymbolGraphs 
import SystemExtras
@preconcurrency import SystemPackage

public 
enum SymbolGraphLoadingError:Error, CustomStringConvertible 
{
    case invalidName(String, culture:ModuleIdentifier)
    case duplicateNamespace(ModuleIdentifier, culture:ModuleIdentifier)
    
    public 
    var description:String 
    {
        switch self 
        {
        case .invalidName(let string, culture: let culture): 
            return "invalid subgraph name '\(string)' (in culture '\(culture)')"
        case .duplicateNamespace(let namespace, culture: let culture): 
            return "duplicate subgraph namespace '\(namespace)' (in culture '\(culture)')"
        }
    }
}
public 
struct ModuleCatalog:Identifiable, Decodable, Sendable 
{
    public
    let id:ModuleIdentifier
    var include:[FilePath] 
    var dependencies:[SymbolGraph.Dependency]
    
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
        self.dependencies = try container.decode([SymbolGraph.Dependency].self, 
            forKey: .dependencies)
    }
    
    public 
    init(id:ID, include:[FilePath], dependencies:[SymbolGraph.Dependency])
    {
        self.id = id 
        self.include = include 
        self.dependencies = dependencies
    }
    public 
    func load(relativeTo prefix:FilePath? = nil) throws -> SymbolGraph
    {
        try Task.checkCancellation()
        var paths:
        (
            extensions:[(name:String, source:FilePath)],
            subgraphs:[ID: FilePath]
        )
        paths.extensions = []
        paths.subgraphs = [:]
        for include:FilePath in self.include
        {
            let include:FilePath = include.isAbsolute  ? include : 
                prefix?.appending(include.components) ?? include
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
                        throw SymbolGraphLoadingError.invalidName(reduced.stem, 
                            culture: self.id)
                    }
                    let namespace:ID 
                    switch identifiers.count
                    {
                    case 1: 
                        namespace = self.id 
                    case 2:
                        namespace = .init(identifiers[1])
                    default: 
                        throw SymbolGraphLoadingError.invalidName(reduced.stem, 
                            culture: self.id)
                    }
                    guard case nil = paths.subgraphs.updateValue(path, forKey: namespace)
                    else 
                    {
                        throw SymbolGraphLoadingError.duplicateNamespace(namespace, 
                            culture: self.id)
                    }
                    
                default: 
                    break
                }
            }
        }

        return .init(id: self.id, dependencies: self.dependencies,
            extensions: try paths.extensions.map 
            {
                (name: $0.name, source: try $0.source.read(String.self))
            }, 
            subgraphs: try paths.subgraphs.map 
            {
                try .init(parsing: try $0.value.read([UInt8].self), 
                    namespace: $0.key,
                    culture: self.id)
            })
    }
}
