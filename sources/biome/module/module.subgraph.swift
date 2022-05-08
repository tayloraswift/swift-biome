import Resource 
import JSON 

extension Module 
{
    enum SubgraphError:Error 
    {
        case id(ID, expected:ID)
    }
    struct Subgraph 
    {        
        let vertices:[Vertex]
        let edges:[Edge]
        let hash:Resource.Version?
        let namespace:Module.ID
        
        init<Location>(loading subgraph:(perpetrator:Module.ID, namespace:Module.ID?), 
            from location:Location, 
            with load:(Location, Resource.Text) async throws -> Resource) async throws 
        {
            let loaded:(json:JSON, hash:Resource.Version?)
            switch try await load(location, .json)
            {
            case    .text   (let string, type: _, version: let version):
                loaded.json = try Grammar.parse(string.utf8, as: JSON.Rule<String.Index>.Root.self)
                loaded.hash = version
            
            case    .binary (let bytes, type: _, version: let version):
                loaded.json = try Grammar.parse(bytes, as: JSON.Rule<Array<UInt8>.Index>.Root.self)
                loaded.hash = version
            }
            try self.init(loading: subgraph, from: loaded)
        }
        private 
        init(loading subgraph:(perpetrator:Module.ID, namespace:Module.ID?), 
            from loaded:(json:JSON, hash:Resource.Version?)) throws 
        {
            self.hash = loaded.hash 
            self.namespace = subgraph.namespace ?? subgraph.perpetrator
            (self.vertices, self.edges) = try loaded.json.lint(["metadata"]) 
            {
                let edges:[Edge]      = try $0.remove("relationships") { try $0.map(  Edge.init(from:)) }
                let vertices:[Vertex] = try $0.remove("symbols")       { try $0.map(Vertex.init(from:)) }
                let module:Module.ID  = try $0.remove("module")
                {
                    try $0.lint(["platform"]) 
                    {
                        Module.ID.init(try $0.remove("name", as: String.self))
                    }
                }
                guard module == subgraph.perpetrator
                else 
                {
                    throw SubgraphError.id(module, expected: subgraph.perpetrator)
                }
                return (vertices, edges)
            }
        }
    }
}
