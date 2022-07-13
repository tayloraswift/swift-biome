import Notebook
import Resources 
import JSON 

extension Module 
{    
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
            articles:[Extension], 
            dependencies:[Dependency]
        
        public 
        init(core:Subgraph, 
            colonies:[Subgraph], 
            articles:[Extension], 
            dependencies:[Dependency]) 
        {
            self.core = core 
            self.colonies = colonies 
            self.articles = articles 
            self.dependencies = dependencies
        }
        
        var edges:[[Edge]] 
        {
            [self.core.edges] + self.colonies.map(\.edges)
        }
    }
    public 
    struct Subgraph:Sendable 
    {
        private(set)
        var vertices:[(id:Symbol.ID, vertex:Vertex)]
        private(set)
        var edges:[Edge]
        let namespace:Module.ID
        
        public 
        init(parsing json:[UInt8], culture:Module.ID, namespace:Module.ID? = nil) throws 
        {
            try self.init(from: try Grammar.parse(json, as: JSON.Rule<Int>.Root.self), 
                culture: culture, namespace: namespace)
        }
        private 
        init(from json:JSON, culture:Module.ID, namespace:Module.ID?) throws 
        {
            let (images, edges):([Image], [Edge]) = try json.lint(["metadata"]) 
            {
                let edges:[Edge]   = try $0.remove("relationships") { try $0.map( Edge.init(from:)) }
                let images:[Image] = try $0.remove("symbols")       { try $0.map(Image.init(from:)) }
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
                    throw SubgraphDecodingError.mismatchedCulture(module, expected: culture)
                }
                return (images, edges)
            }
            
            self.edges = edges 
            if let namespace:Module.ID = namespace
            {
                self.namespace = namespace
                self.vertices = images.compactMap(\.canonical)
                return
            }
            else 
            {
                self.namespace = culture
                self.vertices = []
            }
            self.extend(with: images, of: culture) 
        }
        
        private mutating 
        func extend(with images:[Image], of culture:Module.ID) 
        {
            // about half of the symbols in a typical symbol graph are non-canonical. 
            // (i.e., they are inherited by victims). in theory, these symbols can 
            // recieve documentation through article bindings, but it is very 
            // unlikely that the symbol graph vertices themselves contain 
            // useful information. 
            // 
            // that said, we cannot ignore non-canonical symbols altogether, because 
            // if their canonical base originates from an underscored protocol 
            // (or is implicitly private itself), then the non-canonical symbols 
            // are our only source of information about the canonical base. 
            // 
            // example: UnsafePointer.predecessor() actually originates from 
            // the witness `ss8_PointerPsE11predecessorxyF`, which is part of 
            // the underscored `_Pointer` protocol.
            var vertices:[Symbol.ID: Vertex] = [:], 
                protocols:[Symbol.ID: String] = [:]
            
            for image:Image in images 
            {
                // comb through generic constraints looking for references to 
                // underscored protocols and associatedtypes
                for constraint:Generic.Constraint<Symbol.ID> in image.constraints
                {
                    guard let id:Symbol.ID = constraint.target
                    else 
                    {
                        continue 
                    }
                    if  case (culture, let mythical)? = id.interface, 
                        case "_"? = mythical.name.first
                    {
                        protocols[mythical.id] = mythical.name
                    }
                }
                canonicalization:
                switch image.kind 
                {
                case .synthesized(namespace: culture): 
                    // only infer symbols namespaced to the current module.
                    // it’s possible to encounter symbols namespaced to different 
                    // modules even in a core symbolgraph, if they were inherited 
                    // through conformances to a protocol in a different module.
                    guard vertices.keys.contains(image.id)
                    else 
                    {
                        vertices[image.id] = image.vertex
                        break canonicalization
                    }
                    // already have a copy of this declaration
                    continue 
                    
                case .synthesized(namespace: _):
                    // this namespace is the namespace of the *inferred declaration*, 
                    // not the namespace of the synthesized feature.
                    continue 
                
                case .natural:
                    vertices[image.id] = image.vertex
                    continue 
                }
                guard case (culture, let `protocol`)? = image.id.interface 
                else 
                {
                    continue 
                }
                
                let base:Path = .init(prefix: [`protocol`.name], last: image.vertex.path.last)
                var host:String { image.vertex.path.prefix.joined(separator: ".") }
                
                // fix the first path component of the vertex, so that it points 
                // to the protocol and not the concrete type we discovered it in 
                vertices[image.id]?.path = base
                
                if case true? = image.vertex.frame.availability.general?.unavailable
                {
                    // if the symbol is unconditionally unavailable, generate 
                    // an edge for it:
                    self.edges.append(.init(image.id, is: .member, of: `protocol`.id))
                    print("note: naturalized protocol member '\(base)' from host '\(host)'")
                }
                else if case "_"? = `protocol`.name.first
                {
                    // if the inferred symbol belongs to an underscored protocol, 
                    // generate an edge for it:
                    self.edges.append(.init(image.id, is: .member, of: `protocol`.id))
                    // make a note of the protocol name and identifier
                    protocols[`protocol`.id] = `protocol`.name
                    print("note: naturalized protocol member '\(base)' from host '\(host)'")
                }
            }
            
            self.vertices.reserveCapacity(self.vertices.count + vertices.count + protocols.count)
            for (id, vertex):(Symbol.ID, Vertex) in vertices 
            {
                self.vertices.append((id, vertex))
            }
            // generate vertices for underscored protocols
            for (id, name):(Symbol.ID, String) in protocols 
            {
                let fragments:[Notebook<Highlight, Symbol.ID>.Fragment] = 
                [
                    .init("protocol",   color: .keywordText),
                    .init(" ",          color: .text),
                    .init(name,         color: .identifier),
                ]
                let vertex:Vertex = .init(path: .init(last: name), 
                    color: .protocol, 
                    frame: .init(
                        availability:          .init(), 
                        declaration:           .init(fragments), 
                        signature:             .init(fragments), 
                        generics:               [], 
                        genericConstraints:     [], 
                        extensionConstraints:   [], 
                        comment:                ""))
                self.vertices.append((id, vertex))
                print("note: naturalized underscored protocol '\(name)'")
            }
        }
    }
}
