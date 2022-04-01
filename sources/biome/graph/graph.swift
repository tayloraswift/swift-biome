import Highlight
import Resource
import JSON 

extension Documentation.Catalog 
{
    func load(core descriptor:Module.Graph, 
        with load:(Location, Resource.Text) async throws -> Resource) 
        async throws -> Graph
    {
        try await self.load(graph: descriptor, of: descriptor.namespace, with: load)
    }
    func load(graph descriptor:Module.Graph, of perpetrator:Biome.Module.ID, 
        with load:(Location, Resource.Text) async throws -> Resource) 
        async throws -> Graph
    {
        let graph:Graph 
        switch try await load(descriptor.location, .json)
        {
        case    .text   (let string, type: _, version: let version):
            let json:JSON = try Grammar.parse(string.utf8, as: JSON.Rule<String.Index>.Root.self)
            graph = try .init(from: json, version: version)
        
        case    .binary (let bytes, type: _, version: let version):
            let json:JSON = try Grammar.parse(bytes, as: JSON.Rule<Array<UInt8>.Index>.Root.self)
            graph = try .init(from: json, version: version)
        }
        guard graph.perpetrator == perpetrator
        else 
        {
            throw Graph.ModuleError.mismatched(id: graph.perpetrator)
        }
        return graph
    }
}
struct Graph 
{
    struct LoadingError:Error 
    {
        let underlying:Error
        let module:Biome.Module.ID, 
            bystander:Biome.Module.ID?
        
        init(_ underlying:Error, module:Biome.Module.ID, bystander:Biome.Module.ID?)
        {
            self.underlying = underlying
            self.module     = module
            self.bystander  = bystander
        }
    }
    enum AvailabilityError:Error 
    {
        case duplicate(domain:Biome.Domain, in:Biome.Symbol.ID)
    }
    enum PackageError:Error 
    {
        case duplicate(id:Biome.Package.ID)
    }
    enum ModuleError:Error 
    {
        case mismatchedExtension(id:Biome.Module.ID, expected:Biome.Module.ID, in:Biome.Symbol.ID)
        case mismatched(id:Biome.Module.ID)
        case duplicate(id:Biome.Module.ID)
        case undefined(id:Biome.Module.ID)
    }
    enum SymbolError:Error 
    {
        // global errors 
        case disputed(Vertex, Vertex)
        case undefined(id:Biome.Symbol.ID)
        
        // local errors
        case synthetic(resolution:Biome.USR)
        /// unique id is completely empty
        case unidentified
        /// unique id does not start with a supported language prefix (‘c’ or ‘s’)
        case unsupportedLanguage(code:UInt8)
    }
    
    let perpetrator:Biome.Module.ID
    private 
    let vertices:[Vertex]
    private 
    let edges:[Edge]
    
    let version:Resource.Version?
    
    @usableFromInline
    init(from json:JSON, version:Resource.Version?) throws 
    {
        self.version = version
        (self.perpetrator, self.vertices, self.edges) = try json.lint(["metadata"]) 
        {
            let edges:[Edge]            = try $0.remove("relationships") { try $0.map(Self.decode(edge:)) }
            let vertices:[Vertex]       = try $0.remove("symbols")       { try $0.map(Self.decode(vertex:)) }
            let module:Biome.Module.ID  = try $0.remove("module")
            {
                try $0.lint(["platform"]) 
                {
                    Biome.Module.ID.init(try $0.remove("name", as: String.self))
                }
            }
            return (module, vertices, edges)
        }
    }
    
    func populate(_ edges:inout Set<Edge>) throws
    {
        for edge:Edge in self.edges 
        {
            guard let incumbent:Edge = edges.update(with: edge)
            else 
            {
                continue 
            }
            guard   incumbent.origin      == edge.origin, 
                    incumbent.constraints == edge.constraints 
            else 
            {
                throw EdgeError.disputed(incumbent, edge)
            }
        }
    }
    func populate(_ vertices:inout [Vertex], 
        mythical:inout [Biome.Symbol.ID: Vertex],
        indices:inout [Biome.Symbol.ID: Int]) 
        throws -> Range<Int>
    {
        let start:Int = vertices.endIndex
        for vertex:Vertex in self.vertices 
        {
            // all vertices can have duplicates, even canonical ones, due to 
            // the behavior of `@_exported import`.
            if let duplicate:Int = indices[vertex.id]
            {
                guard vertex ~~ vertices[duplicate]
                else 
                {
                    throw SymbolError.disputed(vertex, vertices[duplicate]) 
                }
            }
            else if vertex.isCanonical 
            {
                indices.updateValue(vertices.endIndex, forKey: vertex.id)
                vertices.append(vertex)
                mythical.removeValue(forKey: vertex.id)
            }
            else if let duplicate:Vertex = mythical.updateValue(vertex, forKey: vertex.id)
            {
                // only add the vertex to the mythical list if we don’t already 
                // have it in the normal list 
                guard vertex ~~ duplicate 
                else 
                {
                    throw SymbolError.disputed(vertex, duplicate) 
                }
            }
        }
        let end:Int = vertices.endIndex
        return start ..< end
    }
}
extension Graph 
{
    static 
    func decode(constraint json:JSON) throws -> SwiftConstraint<Biome.Symbol.ID> 
    {
        try json.lint 
        {
            let verb:SwiftConstraintVerb = try $0.remove("kind") 
            {
                switch try $0.as(String.self) as String
                {
                case "superclass":
                    return .subclasses
                case "conformance":
                    return .implements
                case "sameType":
                    return .is
                case let kind:
                    throw SwiftConstraintError.undefined(kind: kind)
                }
            }
            return .init(
                try    $0.remove("lhs", as: String.self), verb, 
                try    $0.remove("rhs", as: String.self), 
                link: try $0.pop("rhsPrecise", Self.decode(id:)))
        }
    }

    static 
    func decode(id json:JSON) throws -> Biome.Symbol.ID
    {
        let string:String = try json.as(String.self)
        switch try Grammar.parse(string.utf8, as: Biome.USR.Rule<String.Index>.self)
        {
        case .natural(let natural): 
            return natural 
        case let synthesized: 
            throw SymbolError.synthetic(resolution: synthesized)
        }
    }
}
