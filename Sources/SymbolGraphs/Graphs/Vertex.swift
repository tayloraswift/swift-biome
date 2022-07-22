import JSON 
import Notebook

struct Image:Sendable
{
    enum Kind:Sendable
    {
        case natural
        case synthesized(namespace:ModuleIdentifier) // namespace of natural base
    }
    
    let id:SymbolIdentifier
    var kind:Kind
    var vertex:Vertex
    
    public
    var canonical:(id:SymbolIdentifier, vertex:Vertex)?
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
    
    public
    var constraints:FlattenSequence<[[Generic.Constraint<SymbolIdentifier>]]>
    {
        [self.vertex.frame.genericConstraints, self.vertex.frame.extensionConstraints].joined()
    }
}
@frozen public
struct Vertex:Sendable
{
    @frozen public 
    struct Frame:Sendable 
    {
        public
        var availability:Availability 
        public
        var declaration:Notebook<Highlight, SymbolIdentifier> 
        public
        var signature:Notebook<Highlight, Never> 
        public
        var generics:[Generic] 
        public
        var genericConstraints:[Generic.Constraint<SymbolIdentifier>] 
        public
        var extensionConstraints:[Generic.Constraint<SymbolIdentifier>] 
        public
        var comment:String
    }
    
    public 
    var path:Path
    public 
    var community:Community 
    public 
    var frame:Frame
}

extension Image
{
    public 
    init(from json:JSON) throws 
    {
        (self.id, self.kind, self.vertex) = try json.lint 
        {
            let `extension`:(extendedModule:ModuleIdentifier, constraints:[Generic.Constraint<SymbolIdentifier>])? = 
                try $0.pop("swiftExtension")
            {
                let (module, constraints):(String, [Generic.Constraint<SymbolIdentifier>]) = try $0.lint
                {
                    (
                        try $0.remove("extendedModule", as: String.self),
                        try $0.pop("constraints", as: [JSON]?.self) { try $0.map(Generic.Constraint.init(from:)) } ?? []
                    )
                }
                return (.init(module), constraints)
            }
            let generics:(parameters:[Generic], constraints:[Generic.Constraint<SymbolIdentifier>])? = 
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
            
            let (kind, id):(Kind, SymbolIdentifier) = try $0.remove("identifier")
            {
                let string:String = try $0.lint(whitelisting: ["interfaceLanguage"])
                {
                    try $0.remove("precise", as: String.self)
                }
                switch try Grammar.parse(string.utf8, as: USR.Rule<String.Index>.self)
                {
                case .natural(let id): 
                    return (.natural, id)
                case .synthesized(from: let id, for: _): 
                    // synthesized symbols always live in extensions
                    guard let namespace:ModuleIdentifier = `extension`?.extendedModule
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
            
            let declaration:Notebook<Highlight, SymbolIdentifier> = .init(
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

            let availability:Availability? = 
                try $0.pop("availability", as: [JSON]?.self, Availability.init(from:))
            let comment:String? = try $0.pop("docComment")
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
            }
            let frame:Vertex.Frame = .init(
                availability:           availability ?? .init(), 
                declaration:            declaration, 
                signature:              signature, 
                generics:               generics?.parameters ?? [], 
                genericConstraints:     generics?.constraints ?? [], 
                extensionConstraints:  `extension`?.constraints ?? [], 
                comment:                comment ?? "")
            return (id, kind, .init(path: path, community: community, frame: frame))
        }
    }
}
