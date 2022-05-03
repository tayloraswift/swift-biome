import JSON 
import Notebook

struct Vertex
{
    struct Content
    {
        var id:Symbol.ID 
        var path:[String] 
        var color:Symbol.Color 
        var availability:Symbol.Availability 
        var signature:Notebook<Fragment.Color, Never> 
        var declaration:Notebook<Fragment.Color, Symbol.ID> 
        var generics:[Generic] 
        var genericConstraints:[Generic.Constraint<Symbol.ID>] 
        var extensionConstraints:[Generic.Constraint<Symbol.ID>] 
        var extendedModule:Module.ID?
    }
    
    var content:Content
    var comment:String
    var isCanonical:Bool
    
    init(from json:JSON) throws 
    {
        (self.content, self.comment, self.isCanonical) = try json.lint 
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
            
            let declaration:Notebook<Fragment.Color, Symbol.ID> = .init(
                try $0.remove("declarationFragments") { try $0.map(Fragment.init(from:)) })
            let signature:Notebook<Fragment.Color, Never> = .init(
                try $0.remove("names")
            {
                try $0.lint(["title", "navigator"])
                {
                    try $0.remove("subHeading") { try $0.map(Fragment.init(from:)) }
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
            let content:Content = .init(
                id:                     id,
                path:                   path,
                color:                  color, 
                availability:           availability ?? .init(), 
                signature:              signature, 
                declaration:            declaration, 
                generics:               generics?.parameters ?? [], 
                genericConstraints:     generics?.constraints ?? [], 
                extensionConstraints:  `extension`?.constraints ?? [], 
                extendedModule:        `extension`?.extendedModule)
            return (content, comment ?? "", isCanonical)
        }
    }
}
