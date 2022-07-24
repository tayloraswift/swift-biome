import Notebook
import JSON 

extension SymbolGraph 
{
    struct Symbol:Identifiable, Sendable
    {
        enum ID:Hashable, Sendable
        {
            case natural(SymbolIdentifier)
            // namespace of natural base, *not* its culture, and *not* the 
            // culture of the synthesized feature!
            case synthesized(SymbolIdentifier, namespace:ModuleIdentifier) 

            var symbol:SymbolIdentifier 
            {
                switch self 
                {
                case .natural(let symbol), .synthesized(let symbol, namespace: _):
                    return symbol
                }
            }
        }
        
        let id:ID
        var vertex:Vertex<SymbolIdentifier>
    }
}
extension SymbolGraph.Symbol
{
    public 
    init(from json:JSON) throws 
    {
        (self.id, self.vertex) = try json.lint 
        {
            let (extendedModule, extensionConstraints):
            (
                ModuleIdentifier?, 
                [Generic.Constraint<SymbolIdentifier>]
            ) = try $0.pop("swiftExtension")
            {
                try $0.lint
                {
                    (
                        try $0.pop("extendedModule", as: String.self)
                            .map(ModuleIdentifier.init(_:)),
                        try $0.pop("constraints", as: [JSON]?.self) 
                        { 
                            try $0.map(Generic.Constraint<SymbolIdentifier>.init(from:)) 
                        } ?? []
                    )
                }
            } ?? (nil, [])
            let (generics, genericConstraints):
            (
                [Generic], 
                [Generic.Constraint<SymbolIdentifier>]
            ) = try $0.pop("swiftGenerics")
            {
                try $0.lint 
                {
                    (
                        try $0.pop("parameters", as: [JSON]?.self) 
                        { 
                            try $0.map(Generic.init(from:)) 
                        } ?? [],
                        try $0.pop("constraints", as: [JSON]?.self) 
                        { 
                            try $0.map(Generic.Constraint.init(from:)) 
                        } ?? []
                    )
                }
            } ?? ([], [])
            
            let id:ID = try $0.remove("identifier")
            {
                let string:String = try $0.lint(whitelisting: ["interfaceLanguage"])
                {
                    try $0.remove("precise", as: String.self)
                }
                switch try Grammar.parse(string.utf8, as: USR.Rule<String.Index>.self)
                {
                case .natural(let id): 
                    return .natural(id)
                case .synthesized(from: let id, for: _): 
                    // synthesized symbols always live in extensions
                    guard let extendedModule:ModuleIdentifier 
                    else 
                    {
                        // FIXME: we should throw an error instead 
                        fatalError("FIXME")
                    }
                    return .synthesized(id, namespace: extendedModule)
                }
            }
            let path:[String] = try $0.remove("pathComponents") { try $0.map { try $0.as(String.self) } }
            guard let path:Path = .init(path)
            else 
            {
                // FIXME: we should throw an error instead 
                fatalError("FIXME")
            }
            let community:Community = try $0.remove("kind")
            {
                let community:Community = try $0.lint(whitelisting: ["displayName"])
                {
                    try $0.remove("identifier") { try $0.case(of: Community.self) }
                }
                // if the symbol is an operator and it has more than one path component, 
                // consider it a type operator. 
                if case .global(.operator) = community, path.count > 1
                {
                    return .callable(.typeOperator)
                }
                else 
                {
                    return community
                }
            }
            
            let _:AccessLevel = try $0.remove("accessLevel") { try $0.case(of: AccessLevel.self) }
            
            let fragments:Notebook<Highlight, SymbolIdentifier> = .init(
                try $0.remove("declarationFragments") 
            { 
                try $0.map(Notebook<Highlight, SymbolIdentifier>.Fragment.init(from:)) 
            })
            let signature:Notebook<Highlight, Never> = .init(
                try $0.remove("names")
            {
                try $0.lint(whitelisting: ["title", "navigator"])
                {
                    try $0.remove("subHeading") 
                    { 
                        try $0.map(Notebook<Highlight, SymbolIdentifier>.Fragment.init(from:)) 
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
            let _:JSON? = $0.pop("functionSignature")

            let availability:Availability = 
                try $0.pop("availability", as: [JSON]?.self, Availability.init(from:)) ?? .init()
            let comment:String = try $0.pop("docComment")
            {
                try $0.lint(whitelisting: ["uri", "module"]) 
                {
                    try $0.remove("lines")
                    {
                        try $0.map
                        {
                            try $0.lint(whitelisting: ["range"])
                            {
                                try $0.remove("text", as: String.self)
                            }
                        }.joined(separator: "\n")
                    }
                }
            } ?? ""
            let vertex:SymbolGraph.Vertex = .init(path: path,
                community: community, 
                declaration: .init(
                    fragments: fragments, 
                    signature: signature, 
                    availability: availability, 
                    extensionConstraints: extensionConstraints, 
                    genericConstraints: genericConstraints, 
                    generics: generics), 
                comment: comment)
            return (id, vertex)
        }
    }
}
