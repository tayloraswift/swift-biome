import Resource 
import JSON 

extension Module 
{
    struct Subgraph 
    {        
        let vertices:[Vertex]
        let edges:[Edge]
        let hash:Resource.Version?
        let namespace:Module.ID
        
        init<Location>(loading perpetrator:Module.ID, extending namespace:Module.ID? = nil, 
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
                json = try Grammar.parse(bytes, as: JSON.Rule<Array<UInt8>.Index>.Root.self)
                loaded.hash = version
            }
            try self.init(loading: perpetrator, extending: namespace, from: loaded)
        }
        private 
        init(loading perpetrator:Module.ID, extending namespace:Module.ID? = nil, 
            from loaded:(json:JSON, hash:Resource.Version?)) throws 
        {
            self.hash = loaded.hash 
            self.namespace = namespace ?? perpetrator
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
                guard module == perpetrator
                else 
                {
                    throw _ModuleError.mismatched(id: module)
                }
                return (vertices, edges)
            }
        }
    }
}
