import JSON
import SymbolGraphs 
@preconcurrency import SystemPackage

public 
struct SnippetCatalog:Identifiable, Sendable 
{
    public
    let id:ModuleIdentifier
    var sources:[FilePath] 
    var dependencies:[SymbolGraph.Dependency]
    
    public
    init(from json:JSON) throws 
    {
        (self.id, self.sources, self.dependencies) = try json.lint 
        {
            (
                try $0.remove("snippet", as: String.self, ModuleIdentifier.init(_:)),
                try $0.remove("sources", as: [JSON].self)
                {
                    try $0.map { FilePath.init(try $0.as(String.self)) }
                },
                try $0.remove("dependencies", as: [JSON].self) 
                {
                    try $0.map(SymbolGraph.Dependency.init(from:))
                }
            )
        }
    }
    public 
    init(id:ID, sources:[FilePath], dependencies:[SymbolGraph.Dependency])
    {
        self.id = id 
        self.sources = sources 
        self.dependencies = dependencies
    }
}
