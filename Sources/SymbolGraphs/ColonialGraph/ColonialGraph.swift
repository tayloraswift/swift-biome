import JSON
import Notebook
import SymbolSource

struct ColonialGraph:Sendable 
{
    public 
    let namespace:ModuleIdentifier
    var sourcemap:[String: [SourceFeature]]
    var vertices:[SymbolIdentifier: SymbolGraph.Vertex<SymbolIdentifier>],
        edges:[SymbolGraph.Edge<SymbolIdentifier>],
        hints:[SymbolGraph.Hint<SymbolIdentifier>]
    
    @inlinable public 
    init<UTF8>(utf8:UTF8, culture:ModuleIdentifier, namespace:ModuleIdentifier? = nil) throws 
        where UTF8:Collection<UInt8>
    {
        try self.init(from: try JSON.init(parsing: utf8), 
            culture: culture, namespace: namespace)
    }
    public  
    init(from json:JSON, culture:ModuleIdentifier, namespace:ModuleIdentifier? = nil) throws 
    {
        let (symbols, relationships):([SymbolGraph.Symbol], [SymbolGraph.Relationship]) = 
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

            let relationships:[SymbolGraph.Relationship] = 
                try $0.remove("relationships", as: [JSON].self) 
            { 
                try $0.map(SymbolGraph.Relationship.init(from:)) 
            }
            let symbols:[SymbolGraph.Symbol] = 
                try $0.remove("symbols", as: [JSON].self) 
            { 
                try $0.map(SymbolGraph.Symbol.init(from:)) 
            }


            return (symbols, relationships)
        }
        
        self.init(culture: culture, namespace: namespace ?? culture, symbols: symbols, 
            relationships: relationships)
    }
    private 
    init(culture:ModuleIdentifier, namespace:ModuleIdentifier, 
        symbols:[SymbolGraph.Symbol], relationships:[SymbolGraph.Relationship])
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
        self.sourcemap = [:]
        self.vertices = [:]
        self.edges = relationships.map(\.edge)
        self.hints = relationships.compactMap(\.hint)
        // it is possible to naturalize protocol members without naturalizing the 
        // protocols themselves.
        for symbol:SymbolGraph.Symbol in symbols 
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
                self.record(location: symbol.location, of: natural)
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
                let vertex:SymbolGraph.Vertex<SymbolIdentifier> = .init(
                    path: .init(prefix: [mythical.name], last: symbol.vertex.path.last), 
                    shape: symbol.vertex.shape, 
                    declaration: symbol.vertex.declaration, 
                    comment: symbol.vertex.comment)
                
                if case true? = vertex.declaration.availability.general?.unavailable
                {
                    // if the symbol is unconditionally unavailable, generate 
                    // an edge for it:
                    self.edges.append(.init(inferred, is: .member, of: mythical.id))
                    self.vertices[inferred] = vertex
                    self.record(location: symbol.location, of: inferred)
                    print("note: naturalized unavailable protocol member '\(vertex.path)'")
                }
                else if case "_"? = mythical.name.first
                {
                    // if the inferred symbol belongs to an underscored protocol, 
                    // generate an edge for it:
                    self.edges.append(.init(inferred, is: .member, of: mythical.id))
                    self.vertices[inferred] = vertex
                    self.record(location: symbol.location, of: inferred)
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
    private mutating 
    func record(location:SymbolGraph.Symbol.Location?, of symbol:SymbolIdentifier)
    {
        guard let location:SymbolGraph.Symbol.Location 
        else 
        {
            return 
        }
        self.sourcemap[location.uri, default: []].append(.init(line: location.line,
            character: location.character,
            id: symbol))
    }
}
