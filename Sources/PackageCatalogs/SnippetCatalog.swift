import SymbolGraphs 
import SystemExtras
@preconcurrency import SystemPackage

public 
struct SnippetCatalog:Identifiable, Decodable, Sendable 
{
    public
    let id:ModuleIdentifier
    var sources:[FilePath] 
    var dependencies:[SymbolGraph.Dependency]
    
    public 
    enum CodingKeys:String, CodingKey 
    {
        case id = "snippet" 
        case sources 
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
        self.sources = try container.decode([String].self, 
            forKey: .sources).map(FilePath.init(_:))
        self.dependencies = try container.decode([SymbolGraph.Dependency].self, 
            forKey: .dependencies)
    }
    
    public 
    init(id:ID, sources:[FilePath], dependencies:[SymbolGraph.Dependency])
    {
        self.id = id 
        self.sources = sources 
        self.dependencies = dependencies
    }
}
