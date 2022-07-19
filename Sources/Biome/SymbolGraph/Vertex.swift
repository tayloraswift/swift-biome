import JSON 
import Notebook

struct Image:Sendable
{
    enum Kind:Sendable
    {
        case natural
        case synthesized(namespace:Module.ID) // namespace of natural base
    }
    
    let id:Symbol.ID
    var kind:Kind
    var vertex:Vertex
    
    var canonical:(id:Symbol.ID, vertex:Vertex)?
    {
        if case .natural = self.kind 
        {
            return (self.id, self.vertex)
        }
        else 
        {
            return nil
        }
    }
    
    var constraints:FlattenSequence<[[Generic.Constraint<Symbol.ID>]]>
    {
        [self.vertex.frame.genericConstraints, self.vertex.frame.extensionConstraints].joined()
    }
}
public
struct Vertex:Sendable
{
    struct Frame:Sendable 
    {
        var availability:Availability 
        var declaration:Notebook<Highlight, Symbol.ID> 
        var signature:Notebook<Highlight, Never> 
        var generics:[Generic] 
        var genericConstraints:[Generic.Constraint<Symbol.ID>] 
        var extensionConstraints:[Generic.Constraint<Symbol.ID>] 
        var comment:String
    }
    
    var path:Path
    var color:Symbol.Color 
    var frame:Frame
}

extension Image
{
    init(from json:JSON) throws 
    {
        (self.id, self.kind, self.vertex) = try json.lint 
        {
            let `extension`:(extendedModule:Module.ID, constraints:[Generic.Constraint<Symbol.ID>])? = 
                try $0.pop("swiftExtension")
            {
                let (module, constraints):(String, [Generic.Constraint<Symbol.ID>]) = try $0.lint
                {
                    (
                        try $0.remove("extendedModule", as: String.self),
                        try $0.pop("constraints", as: [JSON]?.self) { try $0.map(Generic.Constraint.init(from:)) } ?? []
                    )
                }
                return (.init(module), constraints)
            }
            let generics:(parameters:[Generic], constraints:[Generic.Constraint<Symbol.ID>])? = 
                try $0.pop("swiftGenerics")
            {
                try $0.lint 
                {
                    (
                        try $0.pop("parameters",  as: [JSON]?.self) { try $0.map(Generic.init(from:)) } ?? [],
                        try $0.pop("constraints", as: [JSON]?.self) { try $0.map(Generic.Constraint.init(from:)) } ?? []
                    )
                }
            }
            
            let (kind, id):(Kind, Symbol.ID) = try $0.remove("identifier")
            {
                let string:String = try $0.lint(["interfaceLanguage"])
                {
                    try $0.remove("precise", as: String.self)
                }
                switch try Grammar.parse(string.utf8, as: USR.Rule<String.Index>.self)
                {
                case .natural(let id): 
                    return (.natural, id)
                case .synthesized(from: let id, for: _): 
                    // synthesized symbols always live in extensions
                    guard let namespace:Module.ID = `extension`?.extendedModule
                    else 
                    {
                        // FIXME: we should throw an error instead 
                        fatalError("FIXME")
                    }
                    return (.synthesized(namespace: namespace), id)
                }
            }
            let path:[String] = try $0.remove("pathComponents") { try $0.map { try $0.as(String.self) } }
            guard let path:Path = .init(path)
            else 
            {
                // FIXME: we should throw an error instead 
                fatalError("FIXME")
            }
            let color:Symbol.Color = try $0.remove("kind")
            {
                let color:Symbol.Color = try $0.lint(["displayName"])
                {
                    try $0.remove("identifier") { try $0.case(of: Symbol.Color.self) }
                }
                // if the symbol is an operator and it has more than one path component, 
                // consider it a type operator. 
                if case .global(.operator) = color, path.count > 1
                {
                    return .callable(.typeOperator)
                }
                else 
                {
                    return color
                }
            }
            
            let _:AccessLevel = try $0.remove("accessLevel") { try $0.case(of: AccessLevel.self) }
            
            let declaration:Notebook<Highlight, Symbol.ID> = .init(
                try $0.remove("declarationFragments") 
            { 
                try $0.map(Notebook<Highlight, Symbol.ID>.Fragment.init(from:)) 
            })
            let signature:Notebook<Highlight, Never> = .init(
                try $0.remove("names")
            {
                try $0.lint(["title", "navigator"])
                {
                    try $0.remove("subHeading") 
                    { 
                        try $0.map(Notebook<Highlight, Symbol.ID>.Fragment.init(from:)) 
                    }
                }
            })
            let _:(String, Int, Int)? = try $0.pop("location")
            {
                try $0.lint 
                {
                    let uri:String                  = try $0.remove("uri", as: String.self)
                    let (line, column):(Int, Int)   = try $0.remove("position")
                    {
                        try $0.lint 
                        {
                            (
                                try $0.remove("line",      as: Int.self),
                                try $0.remove("character", as: Int.self)
                            )
                        }
                    }
                    return (uri, line, column)
                }
            }
            let _:Void? = try $0.pop("functionSignature")
            {
                _ in ()
            }

            let availability:Availability? = 
                try $0.pop("availability", as: [JSON]?.self)
            {
                let availability:[(key:Availability.Domain, value:VersionedAvailability)] = 
                try $0.map 
                {
                    try $0.lint
                    {
                        let deprecated:MaskedVersion?? = try
                            $0.pop("deprecated", MaskedVersion.init(exactly:)) ?? 
                            $0.pop("isUnconditionallyDeprecated", as: Bool?.self).flatMap 
                        {
                            (flag:Bool) -> MaskedVersion?? in 
                            flag ? .some(nil) : nil
                        } 
                        // possible to be both unconditionally unavailable and unconditionally deprecated
                        let availability:VersionedAvailability = .init(
                            unavailable: try $0.pop("isUnconditionallyUnavailable", as: Bool?.self) ?? false,
                            deprecated: deprecated,
                            introduced: try $0.pop("introduced", MaskedVersion.init(exactly:)) ?? nil,
                            obsoleted: try $0.pop("obsoleted", MaskedVersion.init(exactly:)) ?? nil, 
                            renamed: try $0.pop("renamed", as: String?.self),
                            message: try $0.pop("message", as: String?.self))
                        let domain:Availability.Domain = try $0.remove("domain") 
                        { 
                            try $0.case(of: Availability.Domain.self) 
                        }
                        return (key: domain, value: availability)
                    }
                }
                return try .init(availability)
            }
            let comment:String? = try $0.pop("docComment")
            {
                try $0.lint(["uri", "module"]) 
                {
                    try $0.remove("lines")
                    {
                        try $0.map
                        {
                            try $0.lint(["range"])
                            {
                                try $0.remove("text", as: String.self)
                            }
                        }.joined(separator: "\n")
                    }
                }
            }
            let frame:Vertex.Frame = .init(
                availability:           availability ?? .init(), 
                declaration:            declaration, 
                signature:              signature, 
                generics:               generics?.parameters ?? [], 
                genericConstraints:     generics?.constraints ?? [], 
                extensionConstraints:  `extension`?.constraints ?? [], 
                comment:                comment ?? "")
            return (id, kind, .init(path: path, color: color, frame: frame))
        }
    }
}
extension Availability 
{
    init(_ items:[(key:Availability.Domain, value:VersionedAvailability)]) throws
    {
        self.init()
        for (key, value):(Availability.Domain, VersionedAvailability) in items
        {
            switch key 
            {
            case .general:
                if case nil = self.general
                {
                    self.general = .init(value)
                }
                else 
                {
                    throw Module.SubgraphDecodingError.duplicateAvailabilityDomain(key)
                }
            
            case .swift:
                if case nil = self.swift 
                {
                    self.swift = .init(value)
                }
                else 
                {
                    throw Module.SubgraphDecodingError.duplicateAvailabilityDomain(key)
                }
            
            case .tools:
                fatalError("unimplemented (yet)")
            
            case .platform(let platform):
                guard case nil = self.platforms.updateValue(value, forKey: platform)
                else 
                {
                    throw Module.SubgraphDecodingError.duplicateAvailabilityDomain(key)
                }
            }
        }
    }
}
