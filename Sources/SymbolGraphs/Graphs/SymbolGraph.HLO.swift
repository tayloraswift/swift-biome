extension SymbolGraph.Subgraph 
{
    public 
    typealias HLO = 
    (
        culture:ModuleIdentifier, 
        namespace:ModuleIdentifier,
        utf8:[UInt8]
    )
}
extension SymbolGraph 
{
    public 
    struct HLO:Identifiable, Sendable 
    {
        public 
        let id:ModuleIdentifier 
        public 
        var dependencies:[Dependency],
            extensions:[Extension]
        public 
        var subgraphs:[Subgraph.HLO]

        public 
        init(id:ID, 
            dependencies:[Dependency] = [], 
            extensions:[Extension] = [], 
            subgraphs:[Subgraph.HLO] = [])
        {
            self.id = id 
            self.dependencies = dependencies 
            self.extensions = extensions 
            self.subgraphs = subgraphs
        }
    }
}