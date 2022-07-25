import Notebook
import JSON 

extension SymbolGraph 
{
    public 
    struct Subgraph:Sendable 
    {
        public 
        let namespace:ModuleIdentifier
        var vertices:[SymbolIdentifier: Vertex<SymbolIdentifier>],
            edges:[Edge<SymbolIdentifier>],
            hints:[Hint<SymbolIdentifier>]
        
        @inlinable public 
        init<UTF8>(parsing json:UTF8, culture:ModuleIdentifier, namespace:ModuleIdentifier) throws 
            where UTF8:Collection, UTF8.Element == UInt8
        {
            try self.init(from: try Grammar.parse(json, as: JSON.Rule<UTF8.Index>.Root.self), 
                culture: culture, namespace: namespace)
        }
        public 
        init(parsing object:HLO) throws 
        {
            try self.init(parsing: object.utf8, 
                culture: object.culture, namespace: object.namespace)
        }
        public  
        init(from json:JSON, culture:ModuleIdentifier, namespace:ModuleIdentifier) throws 
        {
            let (symbols, relationships):([Symbol], [Relationship]) = 
                try json.lint(whitelisting: ["metadata"]) 
            {
                let module:ModuleIdentifier = try $0.remove("module")
                {
                    try $0.lint(whitelisting: ["platform"]) 
                    {
                        ModuleIdentifier.init(try $0.remove("name", as: String.self))
                    }
                }
                guard module == culture
                else 
                {
                    throw SymbolGraphDecodingError.mismatchedCulture(module, expected: culture)
                }

                let relationships:[Relationship] = try $0.remove("relationships") 
                { 
                    try $0.map(Relationship.init(from:)) 
                }
                let symbols:[Symbol] = try $0.remove("symbols") 
                { 
                    try $0.map(Symbol.init(from:)) 
                }


                return (symbols, relationships)
            }
            
            self.init(culture: culture, namespace: namespace, symbols: symbols, 
                relationships: relationships)
        }
        private 
        init(culture:ModuleIdentifier, namespace:ModuleIdentifier, 
            symbols:[Symbol], relationships:[Relationship])
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
            self.namespace = namespace 
            self.vertices = [:]
            self.edges = relationships.map(\.edge)
            self.hints = relationships.compactMap(\.hint)
            // it is possible to naturalize protocol members without naturalizing the 
            // protocols themselves.
            for symbol:Symbol in symbols 
            {
                // comb through generic constraints looking for references to 
                // underscored protocols and associatedtypes
                for constraint:Generic.Constraint<SymbolIdentifier> in 
                [
                    symbol.vertex.declaration.genericConstraints, 
                    symbol.vertex.declaration.extensionConstraints
                ].joined()
                {
                    if  case (culture, let mythical)?? = constraint.target?.interface, 
                        case "_"? = mythical.name.first, 
                        !self.vertices.keys.contains(mythical.id)
                    {
                        self.vertices[mythical.id] = .protocol(named: mythical.name)
                        print("note: naturalized underscored protocol '\(mythical.name)'")
                    }
                }

                switch symbol.id 
                {
                case .natural(let natural):
                    // natural vertices should always overwrite copies we got from  
                    // synthetic inference.
                    self.vertices[natural] = symbol.vertex
                    continue 
                
                case .synthesized(let inferred, namespace: let namespace): 
                    guard namespace == culture 
                    else 
                    {
                        // only infer symbols namespaced to the current module.
                        // note: this namespace is the namespace of the 
                        // *inferred declaration*, not the namespace of the synthesized 
                        // feature.

                        // it’s possible to encounter symbols namespaced to different 
                        // modules even in a core symbolgraph, if they were inherited 
                        // through conformances to a protocol in a different module.
                        continue 
                    }
                    if self.vertices.keys.contains(inferred)
                    {
                        // already have a copy of this declaration
                        continue 
                    }

                    guard case (culture, let mythical)? = inferred.interface 
                    else 
                    {
                        // FIXME: would miss inherited class members
                        continue 
                    }
                    // fix the first path component of the vertex, so that it points 
                    // to the protocol and not the concrete type we discovered it in 
                    let vertex:Vertex<SymbolIdentifier> = .init(
                        path: .init(prefix: [mythical.name], last: symbol.vertex.path.last), 
                        community: symbol.vertex.community, 
                        declaration: symbol.vertex.declaration, 
                        comment: symbol.vertex.comment)
                    self.vertices[inferred] = vertex
                    
                    if case true? = vertex.declaration.availability.general?.unavailable
                    {
                        // if the symbol is unconditionally unavailable, generate 
                        // an edge for it:
                        self.edges.append(.init(inferred, is: .member, of: mythical.id))
                        print("note: naturalized unavailable protocol member '\(vertex.path)'")
                    }
                    else if case "_"? = mythical.name.first
                    {
                        // if the inferred symbol belongs to an underscored protocol, 
                        // generate an edge for it:
                        self.edges.append(.init(inferred, is: .member, of: mythical.id))
                        print("note: naturalized underscored-protocol member '\(vertex.path)'")
                        // make a note of the protocol name and identifier
                        if !self.vertices.keys.contains(mythical.id)
                        {
                            self.vertices[mythical.id] = .protocol(named: mythical.name)
                            print("note: naturalized underscored protocol '\(mythical.name)'")
                        }
                    }
                }
            }
        }
    }
}
