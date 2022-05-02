import JSON 
import Highlight

infix operator ~~ :ComparisonPrecedence

struct Vertex
{
    var isCanonical:Bool
    var id:Symbol.ID,
        color:Symbol.Color, 
        path:[String], 
        availability:Symbol.Availability,
        signature:Notebook<SwiftHighlight, Never>, 
        declaration:Notebook<SwiftHighlight, Symbol.ID>, 
        generics:[Symbol.Generic], 
        genericConstraints:[SwiftConstraint<Symbol.ID>],
        extensionConstraints:[SwiftConstraint<Symbol.ID>],
        extendedModule:Module.ID?, 
        comment:String
    
    static 
    func ~~ (lhs:Self, rhs:Self) -> Bool 
    {
        if  lhs.id                          == rhs.id,
            lhs.color                       == rhs.color, 
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
    
    init(from json:JSON) throws 
    {
        (
            self.isCanonical,
            self.id,
            self.color,
            self.path,
            self.availability,
            self.signature,
            self.declaration,
            self.generics,
            self.genericConstraints,
            self.extensionConstraints,
            self.extendedModule,
            self.comment
        )
        =
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
            let color:Symbol.Color = try $0.remove("kind")
            {
                try $0.lint(["displayName"])
                {
                    try $0.remove("identifier") { try $0.case(of: Symbol.Color.self) }
                }
            }
            let path:[String] = try $0.remove("pathComponents") { try $0.map { try $0.as(String.self) } }
            let _:Symbol.AccessLevel = try $0.remove("accessLevel") { try $0.case(of: Symbol.AccessLevel.self) }
            
            typealias SwiftFragment = (text:String, highlight:SwiftHighlight, link:Symbol.ID?)
            
            let declaration:Notebook<SwiftHighlight, Symbol.ID> = .init(
                try $0.remove("declarationFragments") { try $0.map(Self.fragment(from:)) })
            let signature:Notebook<SwiftHighlight, Never> = try $0.remove("names")
            {
                let signature:[SwiftFragment] = try $0.lint(["title", "navigator"])
                {
                    try $0.remove("subHeading") { try $0.map(Self.fragment(from:)) }
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
                        try $0.pop("constraints", as: [JSON]?.self) { try $0.map(SwiftConstraint.init(from:)) } ?? []
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
                        try $0.pop("parameters",  as: [JSON]?.self) { try $0.map( Symbol.Generic.init(from:)) } ?? [],
                        try $0.pop("constraints", as: [JSON]?.self) { try $0.map(SwiftConstraint.init(from:)) } ?? []
                    )
                }
            }
            let availability:Symbol.Availability? = 
                try $0.pop("availability", as: [JSON]?.self)
            {
                let availability:[(key:Symbol.AvailabilityDomain, value:Symbol.VersionedAvailability)] = 
                try $0.map 
                {
                    try $0.lint
                    {
                        let deprecated:Package.Version?? = try
                            $0.pop("deprecated", Package.Version.init(from:)) ?? 
                            $0.pop("isUnconditionallyDeprecated", as: Bool?.self).flatMap 
                        {
                            (flag:Bool) -> Package.Version?? in 
                            flag ? .some(nil) : nil
                        } 
                        // possible be both unconditionally unavailable and unconditionally deprecated
                        let availability:Symbol.VersionedAvailability = .init(
                            unavailable: try $0.pop("isUnconditionallyUnavailable", as: Bool?.self) ?? false,
                            deprecated: deprecated,
                            introduced: try $0.pop("introduced", Package.Version.init(from:)),
                            obsoleted: try $0.pop("obsoleted", Package.Version.init(from:)), 
                            renamed: try $0.pop("renamed", as: String?.self),
                            message: try $0.pop("message", as: String?.self))
                        let domain:Symbol.AvailabilityDomain = try $0.remove("domain") 
                        { 
                            try $0.case(of: Symbol.AvailabilityDomain.self) 
                        }
                        return (key: domain, value: availability)
                    }
                }
                return .init(availability)
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
            return 
                (
                isCanonical:            isCanonical, 
                id:                     id,
                color:                  color, 
                path:                   path,
                availability:           availability ?? .init(), 
                signature:              signature, 
                declaration:            declaration, 
                generics:               generics?.parameters ?? [], 
                genericConstraints:     generics?.constraints ?? [], 
                extensionConstraints:  `extension`?.constraints ?? [], 
                extendedModule:        `extension`?.extendedModule,
                comment:                comment ?? ""
                )
        }
    }

    private static 
    func fragment(from json:JSON) throws -> 
    (
        text:String, 
        highlight:SwiftHighlight, 
        link:Symbol.ID?
    )
    {
        try json.lint 
        {
            let text:String = try $0.remove("spelling", as: String.self)
            let link:Symbol.ID? = try $0.pop("preciseIdentifier", Symbol.ID.init(from:))
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
extension Symbol.Generic 
{
    fileprivate
    init(from json:JSON) throws 
    {
        (self.name, self.index, self.depth) = try json.lint 
        {
            (
                name:  try $0.remove("name", as: String.self),
                index: try $0.remove("index", as: Int.self),
                depth: try $0.remove("depth", as: Int.self)
            )
        }
    }
}
extension Package.Version 
{
    fileprivate 
    init(from json:JSON) throws 
    {
        self = try json.lint 
        {
            let major:Int = try $0.remove("major", as: Int.self)
            guard let minor:Int = try $0.pop("minor", as: Int.self)
            else 
            {
                return .tag(major: major, nil)
            }
            guard let patch:Int = try $0.pop("patch", as: Int.self)
            else 
            {
                return .tag(major: major, (minor, nil))
            }
            return .tag(major: major, (minor, (patch, nil)))
        }
    }
}
