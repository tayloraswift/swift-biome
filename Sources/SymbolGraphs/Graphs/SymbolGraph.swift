import Resources 
import Notebook
import JSON 

public 
enum SymbolGraphDecodingError:Error, CustomStringConvertible 
{
    case duplicateAvailabilityDomain(Availability.Domain)
    case invalidFragmentColor(String)
    case mismatchedCulture(ModuleIdentifier, expected:ModuleIdentifier)
    
    public 
    var description:String 
    {
        switch self 
        {
        case .duplicateAvailabilityDomain(let domain):
            return "duplicate entries for availability domain '\(domain.rawValue)'"
        case .mismatchedCulture(let id, expected: let expected): 
            return "subgraph culture is '\(id)', expected '\(expected)'"
        case .invalidFragmentColor(let string): 
            return "invalid fragment color '\(string)'"
        }
    }
}

public 
struct SymbolGraph:Sendable 
{
    public private(set)
    var vertices:[(id:SymbolIdentifier, vertex:Vertex)]
    private(set)
    var edges:[Edge]
    public 
    let namespace:ModuleIdentifier
    
    public 
    init(namespace:ModuleIdentifier, 
        vertices:[(id:SymbolIdentifier, vertex:Vertex)] = [], 
        edges:[Edge] = [])
    {
        self.namespace = namespace 
        self.vertices = vertices
        self.edges = edges
    }
    public 
    init(parsing json:[UInt8], 
        culture:ModuleIdentifier, 
        namespace:ModuleIdentifier? = nil) throws 
    {
        try self.init(from: try Grammar.parse(json, as: JSON.Rule<Int>.Root.self), 
            culture: culture, namespace: namespace)
    }
    private 
    init(from json:JSON, 
        culture:ModuleIdentifier, 
        namespace:ModuleIdentifier?) throws 
    {
        let (images, edges):([Image], [Edge]) = try json.lint(whitelisting: ["metadata"]) 
        {
            let edges:[Edge] = try $0.remove("relationships") { try $0.map( Edge.init(from:)) }
            let images:[Image] = try $0.remove("symbols") { try $0.map(Image.init(from:)) }
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
            return (images, edges)
        }
        
        if let namespace:ModuleIdentifier = namespace
        {
            self.init(namespace: namespace, 
                vertices: images.compactMap(\.canonical), 
                edges: edges)
        }
        else 
        {
            self.init(namespace: culture, edges: edges)
            self.extend(with: images, of: culture) 
        }
    }
    
    private mutating 
    func extend(with images:[Image], of culture:ModuleIdentifier) 
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
        var vertices:[SymbolIdentifier: Vertex] = [:], 
            protocols:[SymbolIdentifier: String] = [:]
        // it is possible to naturalize protocol members without naturalizing the 
        // protocols themselves.
        var naturalizations:[SymbolIdentifier: [SymbolIdentifier]] = [:]
        
        for image:Image in images 
        {
            // comb through generic constraints looking for references to 
            // underscored protocols and associatedtypes
            for constraint:Generic.Constraint<SymbolIdentifier> in image.constraints
            {
                guard let id:SymbolIdentifier = constraint.target
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
            // fix the first path component of the vertex, so that it points 
            // to the protocol and not the concrete type we discovered it in 
            vertices[image.id]?.path = base
            
            if case true? = image.vertex.frame.availability.general?.unavailable
            {
                // if the symbol is unconditionally unavailable, generate 
                // an edge for it:
                naturalizations[`protocol`.id, default: []].append(image.id)
            }
            else if case "_"? = `protocol`.name.first
            {
                // if the inferred symbol belongs to an underscored protocol, 
                // generate an edge for it:
                naturalizations[`protocol`.id, default: []].append(image.id)
                // make a note of the protocol name and identifier
                protocols[`protocol`.id] = `protocol`.name
            }
        }
        
        self.vertices.reserveCapacity(self.vertices.count + vertices.count + protocols.count)
        for (id, vertex):(SymbolIdentifier, Vertex) in vertices 
        {
            self.vertices.append((id, vertex))
        }
        // generate vertices for underscored protocols
        for (id, name):(SymbolIdentifier, String) in protocols 
        {
            let fragments:[Notebook<Highlight, SymbolIdentifier>.Fragment] = 
            [
                .init("protocol",   color: .keywordText),
                .init(" ",          color: .text),
                .init(name,         color: .identifier),
            ]
            let vertex:Vertex = .init(path: .init(last: name), 
                community: .protocol, 
                frame: .init(
                    availability:          .init(), 
                    declaration:           .init(fragments), 
                    signature:             .init(fragments), 
                    generics:               [], 
                    genericConstraints:     [], 
                    extensionConstraints:   [], 
                    comment:                ""))
            self.vertices.append((id, vertex))
        }
        if !protocols.isEmpty 
        {
            print("""
                note: naturalized underscored protocols \
                (\(protocols.values.sorted().map { "'\($0)'" }.joined(separator: ", ")))
                """)
        }
        for (`protocol`, members):(SymbolIdentifier, [SymbolIdentifier]) in naturalizations 
        {
            for member:SymbolIdentifier in members 
            {
                self.edges.append(.init(member, is: .member, of: `protocol`))
            }
        }
        if !naturalizations.isEmpty 
        {
            print("""
                note: naturalized \(naturalizations.values.reduce(0) { $0 + $1.count }) \
                protocol members
                """)
        }
    }
}