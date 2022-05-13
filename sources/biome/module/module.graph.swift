import Resource 
import JSON 

extension Module 
{
    public 
    enum GraphError:Error 
    {
        // this is thrown by the BiomeIndex module
        case missing(id:ID)
        case culture(id:ID, expected:ID)
    }
    
    public 
    struct Catalog
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
    public 
    struct Graph:Sendable 
    {
        public 
        struct Dependency:Decodable, Sendable
        {
            public
            var package:Package.ID
            public
            var modules:[Module.ID]
            
            public 
            init(package:Package.ID, modules:[Module.ID])
            {
                self.package = package 
                self.modules = modules 
            }
        }
        
        let core:Subgraph,
            colonies:[Subgraph], 
            articles:[Extension]
        
        let dependencies:[Dependency]
        
        var tag:Resource.Tag? 
        {
            self.colonies.reduce(self.core.tag) 
            {
                $0 * $1.tag
            }
        }
        
        var edges:[[Edge]] 
        {
            [self.core.edges] + self.colonies.map(\.edges)
        }
    }
    struct Subgraph:Sendable 
    {        
        let vertices:[Vertex]
        let edges:[Edge]
        let tag:Resource.Tag?
        let namespace:Module.ID
        
        init(from resource:Resource, culture:Module.ID, namespace:Module.ID? = nil) throws 
        {
            let json:JSON 
            switch resource.payload
            {
            case    .text(let string, type: _):
                json = try Grammar.parse(string.utf8, as: JSON.Rule<String.Index>.Root.self)
            case    .binary(let bytes, type: _):
                json = try Grammar.parse(bytes, as: JSON.Rule<Array<UInt8>.Index>.Root.self)
            }
            try self.init(from: json, tag: resource.tag, culture: culture, namespace: namespace)
        }
        private 
        init(from json:JSON, tag:Resource.Tag?, culture:Module.ID, namespace:Module.ID?) throws 
        {
            self.tag = tag 
            self.namespace = namespace ?? culture
            (self.vertices, self.edges) = try json.lint(["metadata"]) 
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
                guard module == culture
                else 
                {
                    throw GraphError.culture(id: module, expected: culture)
                }
                return (vertices, edges)
            }
        }
    }
}
