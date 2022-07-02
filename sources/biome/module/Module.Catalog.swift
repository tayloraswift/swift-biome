import Resource

extension Module 
{
    public 
    struct Catalog:Sendable
    {
        public 
        let id:ID, 
            dependencies:[Graph.Dependency]
        public 
        var articles:[(name:String, source:Resource)]
        public 
        var graphs:(core:Resource, colonies:[(namespace:ID, graph:Resource)])
        
        public 
        init(id:ID, core:Resource, 
            colonies:[(namespace:ID, graph:Resource)], 
            articles:[(name:String, source:Resource)], 
            dependencies:[Graph.Dependency])
        {
            self.id = id 
            self.articles = articles
            self.graphs.core = core 
            self.graphs.colonies = colonies 
            self.dependencies = dependencies
        }
        
        func graph() throws -> Graph
        {
            .init(core: 
                    try .init(from: self.graphs.core, culture: self.id), 
                colonies: try self.graphs.colonies.map 
                {
                    try .init(from:   $0.graph,       culture: self.id, namespace: $0.namespace)
                }, 
                articles:     self.articles.map 
                {
                        .init(from: $0.source, name: $0.name)
                },
                dependencies: self.dependencies)
        }
    }
}
