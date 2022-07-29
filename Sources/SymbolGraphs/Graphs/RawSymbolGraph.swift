public 
struct RawSymbolGraph:Identifiable, Sendable 
{
    public 
    typealias Subgraph = 
    (
        culture:ModuleIdentifier, 
        namespace:ModuleIdentifier,
        utf8:[UInt8]
    )

    public 
    let id:ModuleIdentifier 
    public 
    var dependencies:[SymbolGraph.Dependency],
        extensions:[SymbolGraph.Extension]
    public 
    var subgraphs:[Subgraph]

    public 
    init(id:ID, 
        dependencies:[SymbolGraph.Dependency] = [], 
        extensions:[SymbolGraph.Extension] = [], 
        subgraphs:[Subgraph] = [])
    {
        self.id = id 
        self.dependencies = dependencies 
        self.extensions = extensions 
        self.subgraphs = subgraphs
    }
}