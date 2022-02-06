import JSON

struct Graph 
{
    var symbols:[Symbol]
    var edges:[Edge]
    
    init(from json:JSON) throws 
    {
        guard   case .object(let graph)     = json, 
                case .object(let module)?   = graph["module"],
                case .array(let symbols)?   = graph["symbols"],
                case .array(let edges)?     = graph["relationships"]
        else 
        {
            throw Graph.DecodingError.init()
        }
        // print(module)
        self.symbols    = try symbols.map(Graph.Symbol.init(from:))
        self.edges      = try   edges.map(Graph.Edge.init(from:))
    }
}

extension Graph
{
    struct DecodingError:Error 
    {
        let file:String, 
            line:Int 
        init(file:String = #file, line:Int = #line)
        {
            self.file = file 
            self.line = line 
        }
    }
    struct Edge:Codable 
    {
        // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/Edge.h
        enum Kind:String, Codable
        {
            case member                     = "memberOf"
            case conforms                   = "conformsTo"
            case subclasses                 = "inheritsFrom"
            case overrides                  = "overrides"
            case requirement                = "requirementOf"
            case optionalRequirement        = "optionalRequirementOf"
            case defaultImplementation      = "defaultImplementationOf"
        }
        struct Origin:Codable
        {
            var id:String 
            var display:String 
            
            enum CodingKeys:String, CodingKey 
            {
                case id         = "identifier"
                case display    = "displayName"
            }
        }
        // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/Edge.cpp
        var kind:Kind 
        var target:String 
        var source:String 
        // if the source inherited docs 
        var origin:Origin?
        
        enum CodingKeys:String, CodingKey 
        {
            case kind   = "kind"
            case target = "target"
            case source = "source"
            case origin = "sourceOrigin"
        }
    }
    struct Symbol:Decodable, Identifiable
    {
        enum Access:String, Codable  
        {
            case `private` 
            case `fileprivate`
            case `internal`
            case `public`
            case `open`
        }

        struct Display:Codable  
        {            
            var title:String
            var subtitle:[SwiftLanguage.Lexeme]
            
            enum CodingKeys:String, CodingKey 
            {
                case title = "title"
                case subtitle = "subHeading"
            }
        }
        struct Location:Decodable 
        {
            var file:String 
            var line:Int 
            var character:Int 
            
            enum CodingKeys:String, CodingKey 
            {
                case file           = "uri"
                case position       = "position"
                enum Position:String, CodingKey 
                {
                    case line       = "line"
                    case character  = "character"
                }
            }
            init(from decoder:Decoder) throws 
            {
                let decoder:KeyedDecodingContainer = try decoder.container(keyedBy: CodingKeys.self)
                self.file       = try decoder.decode(String.self, forKey: .file)
                
                let position:KeyedDecodingContainer = 
                    try decoder.nestedContainer(keyedBy: CodingKeys.Position.self, forKey: .position)
                self.line       = try position.decode(Int.self, forKey: .line)
                self.character  = try position.decode(Int.self, forKey: .character)
            }
        }
        struct Signature:Codable 
        {
            struct Parameter:Codable 
            {
                var label:String 
                var name:String?
                var lexemes:[SwiftLanguage.Lexeme]
                
                enum CodingKeys:String, CodingKey 
                {
                    case label      = "name"
                    case name       = "internalName"
                    case lexemes    = "declarationFragments"
                }
            }
            var parameters:[Parameter]?
            var returns:[SwiftLanguage.Lexeme]
            
            enum Position:String, CodingKey 
            {
                case parameters = "parameters"
                case returns    = "returns"
            }
        }
        struct Constraint:Codable 
        {
            // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/JSON.cpp
            enum Kind:String, Codable 
            {
                case conformance    = "conformance"
                case superclass     = "superclass"
                case equals         = "sameType"
            }
            
            var kind:Kind 
            var lhs:String
            var rhs:String
            var rhsId:String?
            
            enum CodingKeys:String, CodingKey 
            {
                case kind       = "kind"
                case lhs        = "lhs"
                case rhs        = "rhs"
                case rhsId      = "rhsPrecise"
            }
        }
        struct Extension:Codable 
        {
            var module:String 
            var constraints:[Constraint]? 
            
            enum CodingKeys:String, CodingKey 
            {
                case module         = "extendedModule"
                case constraints    = "constraints"
            }
        }
        struct Generic:Codable 
        {
            var name:String 
            var index:Int 
            var depth:Int 
            
            enum CodingKeys:String, CodingKey 
            {
                case name   = "name"
                case index  = "index"
                case depth  = "depth"
            }
        }
        struct Generics:Codable 
        {
            var parameters:[Generic]?
            var constraints:[Constraint]?
            
            enum CodingKeys:String, CodingKey 
            {
                case parameters     = "parameters"
                case constraints    = "constraints"
            }
        }
        struct Comment:Codable 
        {
            struct Line:Codable 
            {
                var text:String 
                
                enum CodingKeys:String, CodingKey 
                {
                    case text = "text"
                }
            }
            var lines:[Line] 
            
            enum CodingKeys:String, CodingKey 
            {
                case lines = "lines"
            }
        }
        
        let id:String
        var access:Access
        var kind:Entrapta.Symbol.Kind 
        var display:Display
        var location:Location? // some symbols are synthetic
        var path:[String]
        var signature:Signature?
        var declaration:[SwiftLanguage.Lexeme]
        var `extension`:Extension?
        var generics:Generics?
        var comment:[String]
        
        enum CodingKeys:String, CodingKey 
        {
            case access         = "accessLevel"
            
            case kind           = "kind"
            enum Kind:String, CodingKey 
            {
                case identifier = "identifier"
            }
            
            case identifier     = "identifier"
            enum Identifier:String, CodingKey 
            {
                case mangled    = "precise"
            }
            
            case display        = "names"
            case location       = "location"
            case path           = "pathComponents"
            case signature      = "functionSignature"
            case declaration    = "declarationFragments"
            case `extension`    = "swiftExtension"
            case generics       = "swiftGenerics"
            case comment        = "docComment"
        }
        
        init(from decoder:Decoder) throws 
        {
            let decoder:KeyedDecodingContainer = try decoder.container(keyedBy: CodingKeys.self)
            
            self.path           = try decoder.decode([String].self, forKey: .path)
            self.access         = try decoder.decode(Access.self, forKey: .access)
            self.display        = try decoder.decode(Display.self, forKey: .display)
            self.declaration    = try decoder.decode([SwiftLanguage.Lexeme].self, forKey: .declaration)
            
            self.location       = try decoder.decodeIfPresent(Location.self, forKey: .location)
            self.signature      = try decoder.decodeIfPresent(Signature.self, forKey: .signature)
            self.extension      = try decoder.decodeIfPresent(Extension.self, forKey: .extension)
            self.generics       = try decoder.decodeIfPresent(Generics.self, forKey: .generics)
            
            if let comment:Comment = try decoder.decodeIfPresent(Comment.self, forKey: .comment) 
            {
                self.comment    = comment.lines.map(\.text)
            }
            else 
            {
                self.comment    = []
            }
            
            self.kind           = try decoder.nestedContainer(keyedBy: CodingKeys.Kind.self, forKey: .kind)
                .decode(Entrapta.Symbol.Kind.self, forKey: .identifier)
            self.id             = try decoder.nestedContainer(keyedBy: CodingKeys.Identifier.self, forKey: .identifier)
                .decode(String.self, forKey: .mangled)
        }
    }
}
extension Graph.Symbol.Location:CustomStringConvertible 
{
    var description:String 
    {
        "\(self.file):\(self.line):\(self.character)"
    }
}
extension Graph.Symbol.Signature:CustomStringConvertible 
{
    var description:String 
    {
        "\(self.parameters?.flatMap(\.lexemes).map(\.text).joined() ?? "<unavailable>")\(self.returns.map(\.text).joined())"
    }
}
extension Graph.Symbol:CustomStringConvertible 
{
    var description:String 
    {
        """
        \(self.kind) \(self.path) (\(self.access), \(self.id))
        {
            display:        \(self.display.subtitle.map(\.text).joined())
            signature:      \(self.signature?.description ?? "<unavailable>")
            declaration:    \(self.declaration.map(\.text).joined())
            location:       \(self.location?.description ?? "<synthesized>")
            comment: 
            '''
            \(self.comment.map { "\($0)\n" }.joined())'''
        }
        """
    }
}
