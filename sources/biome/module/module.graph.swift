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
        var graphs:(core:Location, bystanders:[(namespace:ID, graph:Location)])
        public 
        var articles:[(name:String, source:Location)]
        
        func load(with loader:(Location, Resource.Text) async throws -> Resource) 
            async throws -> Graph
        {
            let core:Subgraph = try await .init(
                loading: self.id, from: self.graphs.core, with: loader)
            var extensions:[Subgraph] = []
            for (namespace, location):(Module.ID, Location) in self.extensions 
            {
                extensions.append(try await .init(
                    loading: self.id, extending: namespace, from: location, with: loader))
            }
            return .init(core: core, extensions: extensions, 
                dependencies: self.dependencies)
        }
    }
    
    struct Graph 
    {
        struct Dependency:Decodable
        {
            let package:Package.ID
            let modules:[Module.ID]
        }
        
        private(set)
        var core:Subgraph,
            extensions:[Subgraph],
            dependencies:[Dependency]
        
        var hash:Resource.Version? 
        {
            self.extensions.reduce(self.core.hash) 
            {
                $0 * $1.hash
            }
        }
        
        var edges:[[Edge]] 
        {
            [self.core.edges] + self.extensions.map(\.edges)
        }
    }
}
