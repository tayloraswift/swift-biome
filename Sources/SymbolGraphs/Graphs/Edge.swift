import Grammar 
import JSON

@frozen public 
struct Edge:Hashable, Sendable
{
    // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/Edge.h
    @frozen public
    enum Kind:String, CustomStringConvertible, Sendable
    {
        case member                 = "memberOf"
        case conformer              = "conformsTo"
        case subclass               = "inheritsFrom"
        case override               = "overrides"
        case requirement            = "requirementOf"
        case optionalRequirement    = "optionalRequirementOf"
        case defaultImplementation  = "defaultImplementationOf"
        
        @inlinable public
        var description:String 
        {
            switch self 
            {
            case .member:                   return "member"
            case .conformer:                return "conformer"
            case .subclass:                 return "subclass"
            case .override:                 return "override"
            case .requirement:              return "requirement"
            case .optionalRequirement:      return "optional requirement"
            case .defaultImplementation:    return "default implementation"
            }
        }
    }
    // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/Edge.cpp
    public 
    var kind:Kind?
    public 
    var source:SymbolIdentifier
    public 
    var target:SymbolIdentifier
    public 
    var origin:SymbolIdentifier?
    public 
    var constraints:[Generic.Constraint<SymbolIdentifier>]
    
    init(_ source:SymbolIdentifier, is kind:Kind, of target:SymbolIdentifier)
    {
        self.kind = kind 
        self.source = source 
        self.target = target 
        self.origin = nil 
        self.constraints = []
    }
}
extension Edge 
{
    init(from json:JSON) throws
    {
        (self.kind, self.origin, source: self.source, target: self.target, self.constraints) = 
            try json.lint(whitelisting: ["targetFallback"])
        {
            var kind:Edge.Kind? = try $0.remove("kind") { try $0.case(of: Edge.Kind.self) }
            let target:SymbolIdentifier = try $0.remove("target", SymbolIdentifier.init(from:))
            let origin:SymbolIdentifier? = try $0.pop("sourceOrigin")
            {
                try $0.lint(whitelisting: ["displayName"])
                {
                    try $0.remove("identifier", SymbolIdentifier.init(from:))
                }
            }
            let usr:USR = try $0.remove("source")
            {
                let text:String = try $0.as(String.self)
                return try Grammar.parse(text.utf8, as: USR.Rule<String.Index>.self)
            }
            let source:SymbolIdentifier
            switch (kind, usr)
            {
            case (_,       .natural(let natural)): 
                source  = natural 
            // synthesized symbols can only be members of the type in their id
            case (.member, .synthesized(from: let generic, for: target)):
                source  = generic 
                kind    = nil 
            case (_, _):
                fatalError("unimplemented")
                //throw SymbolError.synthetic(resolution: invalid)
            }
            // only 'conformsTo' edges may contain constraints 
            let constraints:[Generic.Constraint<SymbolIdentifier>] 
            if case .conformer = kind 
            {
                constraints = try $0.pop("swiftConstraints", as: [JSON]?.self) 
                { 
                    try $0.map(Generic.Constraint.init(from:)) 
                } ?? []
            }
            else 
            {
                constraints = []
            }
            return (kind, origin: origin, source: source, target: target, constraints)
        }
    }
}
