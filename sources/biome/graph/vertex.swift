import JSON 
import Highlight

infix operator ~~ :ComparisonPrecedence

extension Graph 
{
    struct Vertex
    {
        var isCanonical:Bool
        var id:Symbol.ID,
            kind:Symbol.Kind, 
            path:[String], 
            signature:Notebook<SwiftHighlight, Never>, 
            declaration:Notebook<SwiftHighlight, Symbol.ID>, 
            `extension`:(extendedModule:Module.ID, constraints:[SwiftConstraint<Symbol.ID>])?,
            generics:(parameters:[Symbol.Generic], constraints:[SwiftConstraint<Symbol.ID>])?,
            availability:[(key:Biome.Domain, value:Symbol.Availability)],
            comment:String
        
        static 
        func ~~ (lhs:Self, rhs:Self) -> Bool 
        {
            if  lhs.id                          == rhs.id,
                lhs.kind                        == rhs.kind, 
                lhs.extension?.extendedModule   == rhs.extension?.extendedModule,
                lhs.extension?.constraints      == rhs.extension?.constraints,
                lhs.generics?.parameters        == rhs.generics?.parameters,
                lhs.generics?.constraints       == rhs.generics?.constraints,
                lhs.comment                     == rhs.comment
            {
                return true 
            }
            else 
            {
                return false
            }
        }
    }
    
    static 
    func decode(vertex json:JSON) throws -> Vertex
    {
        try json.lint 
        {
            let (id, isCanonical):(Symbol.ID, Bool) = try $0.remove("identifier")
            {
                let string:String = try $0.lint(["interfaceLanguage"])
                {
                    try $0.remove("precise", as: String.self)
                }
                switch try Grammar.parse(string.utf8, as: URI.Rule<String.Index, UInt8>.USR.self)
                {
                case .natural(let id): 
                    return (id, true)
                case .synthesized(from: let id, for: _): 
                    return (id, false)
                }
            }
            let kind:Symbol.Kind = try $0.remove("kind")
            {
                try $0.lint(["displayName"])
                {
                    try $0.remove("identifier") { try $0.case(of: Symbol.Kind.self) }
                }
            }
            let path:[String] = try $0.remove("pathComponents") { try $0.map { try $0.as(String.self) } }
            let _:Symbol.AccessLevel = try $0.remove("accessLevel") { try $0.case(of: Symbol.AccessLevel.self) }
            
            typealias SwiftFragment = (text:String, highlight:SwiftHighlight, link:Symbol.ID?)
            
            let declaration:Notebook<SwiftHighlight, Symbol.ID> = .init(
                try $0.remove("declarationFragments") { try $0.map(Self.decode(fragment:)) })
            let signature:Notebook<SwiftHighlight, Never> = try $0.remove("names")
            {
                let signature:[SwiftFragment] = try $0.lint(["title", "navigator"])
                {
                    try $0.remove("subHeading") { try $0.map(Self.decode(fragment:)) }
                }
                return Notebook<SwiftHighlight, Symbol.ID>.init(signature).compactMapLinks 
                {
                    _ in Never?.none
                }
            }
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
            let `extension`:(extendedModule:Module.ID, constraints:[SwiftConstraint<Symbol.ID>])? = 
                try $0.pop("swiftExtension")
            {
                let (module, constraints):(String, [SwiftConstraint<Symbol.ID>]) = try $0.lint
                {
                    (
                        try $0.remove("extendedModule", as: String.self),
                        try $0.pop("constraints", as: [JSON]?.self) { try $0.map(Self.decode(constraint:)) } ?? []
                    )
                }
                return (.init(module), constraints)
            }
            let generics:(parameters:[Symbol.Generic], constraints:[SwiftConstraint<Symbol.ID>])? = 
                try $0.pop("swiftGenerics")
            {
                try $0.lint 
                {
                    (
                        try $0.pop("parameters",  as: [JSON]?.self) { try $0.map(Self.decode(generic:)) }    ?? [],
                        try $0.pop("constraints", as: [JSON]?.self) { try $0.map(Self.decode(constraint:)) } ?? []
                    )
                }
            }
            let availability:[(key:Biome.Domain, value:Symbol.Availability)]? = 
                try $0.pop("availability", as: [JSON]?.self)
            {
                try $0.map 
                {
                    try $0.lint
                    {
                        let deprecated:Package.Version?? = try
                            $0.pop("deprecated", Self.decode(version:)) ?? 
                            $0.pop("isUnconditionallyDeprecated", as: Bool?.self).flatMap 
                        {
                            (flag:Bool) -> Package.Version?? in 
                            flag ? .some(nil) : nil
                        } 
                        // possible be both unconditionally unavailable and unconditionally deprecated
                        let availability:Symbol.Availability = .init(
                            unavailable: try $0.pop("isUnconditionallyUnavailable", as: Bool?.self) ?? false,
                            deprecated: deprecated,
                            introduced: try $0.pop("introduced", Self.decode(version:)),
                            obsoleted: try $0.pop("obsoleted", Self.decode(version:)), 
                            renamed: try $0.pop("renamed", as: String?.self),
                            message: try $0.pop("message", as: String?.self))
                        let domain:Biome.Domain = try $0.remove("domain") { try $0.case(of: Biome.Domain.self) }
                        return (key: domain, value: availability)
                    }
                }
            }
            let comment:String? = try $0.pop("docComment")
            {
                try $0.lint 
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
            return .init(
                isCanonical:    isCanonical, 
                id:             id,
                kind:           kind, 
                path:           path,
                signature:      signature, 
                declaration:    declaration, 
                extension:      `extension`, 
                generics:       generics, 
                availability:   availability ?? [], 
                comment:        comment ?? "")
        }
    }
    private static 
    func decode(version json:JSON) throws -> Package.Version
    {
        try json.lint 
        {
            .init(
                major: try $0.remove("major", as: Int.self),
                minor: try    $0.pop("minor", as: Int.self),
                patch: try    $0.pop("patch", as: Int.self))
        }
    }
    private static 
    func decode(generic json:JSON) throws -> Symbol.Generic
    {
        try json.lint 
        {
            .init(
                name:  try $0.remove("name", as: String.self),
                index: try $0.remove("index", as: Int.self),
                depth: try $0.remove("depth", as: Int.self))
        }
    }
    private static 
    func decode(fragment json:JSON) throws -> 
    (
        text:String, 
        highlight:SwiftHighlight, 
        link:Symbol.ID?
    )
    {
        try json.lint 
        {
            let text:String = try $0.remove("spelling", as: String.self)
            let link:Symbol.ID? = try $0.pop("preciseIdentifier", Self.decode(id:))
            let highlight:SwiftHighlight = try $0.remove("kind")
            {
                // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/DeclarationFragmentPrinter.cpp
                switch try $0.as(String.self) as String
                {
                case "keyword":
                    switch text 
                    {
                    case "init", "deinit", "subscript":
                                            return .keywordIdentifier
                    default:                return .keywordText
                    }
                case "attribute":           return .attribute
                case "number":              return .number
                case "string":              return .string
                case "identifier":          return .identifier
                case "typeIdentifier":      return .type
                case "genericParameter":    return .generic
                case "internalParam":       return .parameter
                case "externalParam":       return .argument
                case "text":                return .text
                case let kind:
                    throw SwiftFragmentError.undefined(kind: kind)
                }
            }
            return (text, highlight, link)
        }
    }
}
