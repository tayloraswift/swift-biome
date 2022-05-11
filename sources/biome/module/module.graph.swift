import Resource 

extension Module 
{
    public 
    struct Catalog<Location>
    {
        public 
        let id:ID, 
            dependencies:[Graph.Dependency]
        public 
        var articles:[(name:String, source:Location)]
        public 
        var graphs:(core:Location, colonies:[(namespace:ID, graph:Location)])
        
        public 
        init(id:ID, core:Location, 
            colonies:[(namespace:ID, graph:Location)], 
            articles:[(name:String, source:Location)], 
            dependencies:[Graph.Dependency])
        {
            self.id = id 
            self.articles = articles
            self.graphs.core = core 
            self.graphs.colonies = colonies 
            self.dependencies = dependencies
        }
        
        func load(with loader:(Location, Resource.Text) async throws -> Resource) 
            async throws -> Graph
        {
            let core:Subgraph = try await 
                .init(loading: (self.id, nil), from: self.graphs.core, with: loader)
            var colonies:[Subgraph] = []
                colonies.reserveCapacity(self.graphs.colonies.count)
            for (namespace, location):(Module.ID, Location) in self.graphs.colonies 
            {
                colonies.append(try await 
                    .init(loading: (self.id, namespace), from: location, with: loader))
            }
            var articles:[Extension] = []
                articles.reserveCapacity(self.articles.count)
            for (name, location):(String, Location) in self.articles 
            {
                articles.append(try await 
                    .init(loading: name, from: location, with: loader))
            }
            return .init(core: core, colonies: colonies, articles: articles,
                dependencies: self.dependencies)
        }
    }
    public 
    struct Graph:Sendable 
    {
        public 
        struct Dependency:Decodable, Sendable
        {
            let package:Package.ID
            let modules:[Module.ID]
        }
        
        let core:Subgraph,
            colonies:[Subgraph], 
            articles:[Extension]
        
        let dependencies:[Dependency]
        
        var hash:Resource.Version? 
        {
            self.colonies.reduce(self.core.hash) 
            {
                $0 * $1.hash
            }
        }
        
        var edges:[[Edge]] 
        {
            [self.core.edges] + self.colonies.map(\.edges)
        }
    }
}
