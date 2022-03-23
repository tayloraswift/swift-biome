import Highlight
import JSON 

enum Graph 
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
    enum PackageIdentifierError:Error 
    {
        case duplicate(id:Biome.Package.ID)
    }
    enum ModuleIdentifierError:Error 
    {
        case mismatchedExtension(id:Biome.Module.ID, expected:Biome.Module.ID, in:Biome.Symbol.ID)
        case mismatched(id:Biome.Module.ID)
        case duplicate(id:Biome.Module.ID)
        case undefined(id:Biome.Module.ID)
    }
    enum SymbolIdentifierError:Error 
    {
        // global errors 
        case duplicate(id:Biome.Symbol.ID)
        case undefined(id:Biome.Symbol.ID)
        
        // local errors
        case synthetic(resolution:Biome.USR)
        /// unique id is completely empty
        case empty
        /// unique id does not start with a supported language prefix (‘c’ or ‘s’)
        case unsupportedLanguage(code:UInt8)
    }
    
    static 
    func decode(module json:JSON) throws -> (module:Biome.Module.ID, vertices:[Vertex], edges:[Edge])
    {
        try json.lint(["metadata"]) 
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
            throw SymbolIdentifierError.synthetic(resolution: synthesized)
        }
    }
}
