import JSON
import Highlight

infix operator ~~ :ComparisonPrecedence

extension Biome.Module.ID 
{
    init(from json:JSON?) throws 
    {
        switch json
        {
        case .string(let module)?:
            self = .init(module)
        default:
            throw Biome.DecodingError<Self>.invalid(value: json, key: nil)
        }
    }
}
extension Biome 
{
    typealias Target = 
    (
        module:Module.ID, 
        bystanders:[Module.ID]
    )
    struct Vertex
    {
        var isCanonical:Bool
        var id:Symbol.ID,
            kind:Symbol.Kind, 
            path:[String], 
            signature:Notebook<SwiftHighlight, Never>, 
            declaration:Notebook<SwiftHighlight, Symbol.ID>, 
            extends:(module:Module.ID, where:[SwiftConstraint<Symbol.ID>])?,
            generic:(parameters:[Symbol.Generic], constraints:[SwiftConstraint<Symbol.ID>])?,
            availability:[(key:Biome.Domain, value:Biome.Availability)],
            comment:String
        
        static 
        func ~~ (lhs:Self, rhs:Self) -> Bool 
        {
            if  lhs.id                      == rhs.id,
                lhs.kind                    == rhs.kind, 
                lhs.extends?.module         == rhs.extends?.module,
                lhs.extends?.where          == rhs.extends?.where,
                lhs.generic?.parameters     == rhs.generic?.parameters,
                lhs.generic?.constraints    == rhs.generic?.constraints,
                lhs.comment                 == rhs.comment
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
    func decode(module json:JSON) throws -> (module:Module.ID, vertices:[Vertex], edges:[Edge])
    {
        typealias DecodingError = Biome.DecodingError<[Symbol]>
        
        guard   case .object(let symbolgraph)   = json, 
                case .object(let module)?       = symbolgraph["module"],
                case .array(let symbols)?       = symbolgraph["symbols"],
                case .array(let edges)?         = symbolgraph["relationships"]
        else 
        {
            throw DecodingError.invalid(value: json, key: nil)
        }
        
        let decoded:(module:Module.ID, vertices:[Vertex], edges:[Edge])
        decoded.module      = try .init(from: module["name"])
        decoded.edges       = try edges.map(Edge.init(from:))
        decoded.vertices    = try symbols.map
        {
            guard case .object(let items) = $0 
            else 
            {
                throw DecodingError.invalid(value: $0, key: "symbols[_:]")
            }
            return try Self.decode(symbol: items)
        }
        return decoded
    }
    
    static 
    func decode(symbol json:[String: JSON]) throws -> Vertex
    {
        typealias DecodingError = Biome.DecodingError<Symbol>
        
        var items:[String: JSON] = json
        defer 
        {
            if !items.isEmpty 
            {
                print("warning: unused json keys \(items) in symbol descriptor")
            }
        }
        // decode id and kind 
        let id:Symbol.ID
        let isCanonical:Bool
        switch items.removeValue(forKey: "identifier")
        {
        case .object(var items)?: 
            defer 
            {
                items["interfaceLanguage"] = nil 
                
                if !items.isEmpty 
                {
                    print("warning: unused json keys \(items) in 'identifier'")
                }
            }
            switch items.removeValue(forKey: "precise")
            {
            case .string(let text)?:
                switch try Grammar.parse(text.utf8, as: USR.Rule<String.Index>.self)
                {
                case .natural(let natural): 
                    id = natural 
                    isCanonical = true 
                case .synthesized(from: let generic, for: _): 
                    id = generic 
                    isCanonical = false 
                }
            case let value:
                throw DecodingError.invalid(value: value, key: "identifier.precise")
            }
        case let value:
            throw DecodingError.invalid(value: value, key: "identifier")
        }
        
        let kind:Symbol.Kind
        switch items.removeValue(forKey: "kind")
        {
        case .object(var items)?: 
            defer 
            {
                // ignore 
                items["displayName"] = nil
                if !items.isEmpty 
                {
                    print("warning: unused json keys \(items) in 'kind'")
                }
            }
            switch items.removeValue(forKey: "identifier")
            {
            case .string(let text)?:
                guard let `case`:Symbol.Kind = .init(rawValue: text)
                else 
                {
                    throw DecodingError.invalid(value: .string(text), key: "kind.identifier")
                }
                kind = `case`
            case let value:
                throw DecodingError.invalid(value: value, key: "kind.identifier")
            }
        case let value:
            throw DecodingError.invalid(value: value, key: "kind")
        }
        // decode path 
        let path:[String]
        switch items.removeValue(forKey: "pathComponents")
        {
        case .array(let elements)?:
            path = try elements.map 
            {
                guard case .string(let text) = $0 
                else 
                {
                    throw DecodingError.invalid(value: $0, key: "pathComponents[_:]")
                }
                return text 
            }
        case let value:
            throw DecodingError.invalid(value: value, key: "pathComponents")
        }
        // decode access level 
        switch items.removeValue(forKey: "accessLevel")
        {
        case    .string("private")?,
                .string("fileprivate")?,
                .string("internal")?,
                .string("public")?,
                .string("open")?: 
            break // don’t have a use for this yet 
        case let value: 
            throw DecodingError.invalid(value: value, key: "accessLevel")
        }
        // decode display title and signature
        let signature:Notebook<SwiftHighlight, Never> 
        switch items.removeValue(forKey: "names")
        {
        case .object(var items)?: 
            defer 
            {
                // navigator does not tell us any useful information 
                items["navigator"] = nil
                if !items.isEmpty 
                {
                    print("warning: unused json keys \(items) in 'names' (path: \(path))")
                }
            }
            // decode display title and signature
            switch items.removeValue(forKey: "title")
            {
            case .string(_)?: 
                // discard title
                break 
            case let value: 
                throw DecodingError.invalid(value: value, key: "names.title")
            }
            switch items.removeValue(forKey: "subHeading")
            {
            case .array(let elements)?: 
                signature = Notebook<SwiftHighlight, Symbol.ID>.init(try elements.map(Self.decode(lexeme:)))
                    .compactMapLinks 
                {
                    _ in Never?.none
                }
            case let value: 
                throw DecodingError.invalid(value: value, key: "names.subHeading")
            }
        case let value: 
            throw DecodingError.invalid(value: value, key: "names")
        }
        // decode declaration 
        let declaration:Notebook<SwiftHighlight, Symbol.ID>
        switch items.removeValue(forKey: "declarationFragments")
        {
        case .array(let elements)?: 
            declaration = .init(try elements.map(Self.decode(lexeme:)))
        case let value: 
            throw DecodingError.invalid(value: value, key: "declarationFragments")
        }
        // decode source location
        switch items.removeValue(forKey: "location")
        {
        case nil, .null?: 
            break 
        case .object(var items)?: 
            defer 
            {
                if !items.isEmpty 
                {
                    print("warning: unused json keys \(items) in 'location'")
                }
            }
            switch items.removeValue(forKey: "uri")
            {
            case .string(_)?: 
                break 
            case let value: 
                throw DecodingError.invalid(value: value, key: "location.uri")
            }
            switch items.removeValue(forKey: "position")
            {
            case .object(var items)?: 
                defer 
                {
                    if !items.isEmpty 
                    {
                        print("warning: unused json keys \(items) in 'location.position'")
                    }
                }
                switch items.removeValue(forKey: "line")
                {
                case .number(_)?: 
                    break 
                case let value: 
                    throw DecodingError.invalid(value: value, key: "location.position.line")
                }
                switch items.removeValue(forKey: "character")
                {
                case .number(_)?: 
                    break 
                case let value: 
                    throw DecodingError.invalid(value: value, key: "location.position.character")
                }
            case let value: 
                throw DecodingError.invalid(value: value, key: "location.position")
            }
        case let value?: 
            throw DecodingError.invalid(value: value, key: "location")
        }
        // decode function signature
        // let function:(parameters:[Symbol.Parameter], returns:[SwiftLanguage.Lexeme<Symbol.ID>])?
        switch items.removeValue(forKey: "functionSignature")
        {
        case nil, .null?: 
            break // function = nil
        case .object(var items)?: 
            defer 
            {
                if !items.isEmpty 
                {
                    print("warning: unused json keys \(items) in 'functionSignature'")
                }
            }
            // let parameters:[Symbol.Parameter], 
            //     returns:[SwiftLanguage.Lexeme<Symbol.ID>]
            switch items.removeValue(forKey: "parameters")
            {
            case nil, .null?:
                break // parameters = []
            case .array(_)?: 
                break // parameters = try elements.map(Symbol.Parameter.init(from:))
            case let value?: 
                throw DecodingError.invalid(value: value, key: "functionSignature.parameters")
            }
            switch items.removeValue(forKey: "returns")
            {
            case .array(_)?: 
                // TODO: do something with these
                break // try elements.map(Self.decode(lexeme:))
            case let value: 
                throw DecodingError.invalid(value: value, key: "functionSignature.returns")
            }
            // function = (parameters, returns)
        case let value?: 
            throw DecodingError.invalid(value: value, key: "functionSignature")
        }
        // decode extension info
        let extends:(module:Module.ID, where:[SwiftConstraint<Symbol.ID>])?
        switch items.removeValue(forKey: "swiftExtension")
        {
        case nil, .null?: 
            extends = nil
        case .object(var items)?: 
            defer 
            {
                if !items.isEmpty 
                {
                    print("warning: unused json keys \(items) in 'swiftExtension'")
                }
            }
            let module:Module.ID = try .init(from: items.removeValue(forKey: "extendedModule"))
            let constraints:[SwiftConstraint<Symbol.ID>]
            switch items.removeValue(forKey: "constraints")
            {
            case nil, .null?:
                constraints = []
            case .array(let elements)?: 
                constraints = try elements.map(Self.decode(constraint:)) 
            case let value?: 
                throw DecodingError.invalid(value: value, key: "swiftExtension.constraints")
            }
            extends = (module, constraints)
        case let value?: 
            throw DecodingError.invalid(value: value, key: "swiftExtension")
        }
        // decode generics info 
        let generic:(parameters:[Symbol.Generic], constraints:[SwiftConstraint<Symbol.ID>])?
        switch items.removeValue(forKey: "swiftGenerics")
        {
        case nil, .null?: 
            generic = nil
        case .object(var items)?: 
            defer 
            {
                if !items.isEmpty 
                {
                    print("warning: unused json keys \(items) in 'swiftGenerics'")
                }
            }
            let parameters:[Symbol.Generic], 
                constraints:[SwiftConstraint<Symbol.ID>]
            switch items.removeValue(forKey: "parameters")
            {
            case nil, .null?:
                parameters = []
            case .array(let elements)?: 
                parameters = try elements.map(Symbol.Generic.init(from:)) 
            case let value?: 
                throw DecodingError.invalid(value: value, key: "swiftGenerics.parameters")
            }
            switch items.removeValue(forKey: "constraints")
            {
            case nil, .null?:
                constraints = []
            case .array(let elements)?: 
                constraints = try elements.map(Self.decode(constraint:)) 
            case let value?: 
                throw DecodingError.invalid(value: value, key: "swiftGenerics.constraints")
            }
            generic = (parameters, constraints)
        case let value?: 
            throw DecodingError.invalid(value: value, key: "swiftGenerics")
        }
        // decode availability
        let availability:[(key:Domain, value:Availability)]
        switch items.removeValue(forKey: "availability")
        {
        case nil, .null?:
            availability = []
        case .array(let elements)?: 
            availability = try elements.map 
            {
                let item:(key:Domain, value:Availability)
                guard case .object(var items) = $0 
                else 
                {
                    throw DecodingError.invalid(value: $0, key: "availability[_:]")
                }
                defer 
                {
                    if !items.isEmpty 
                    {
                        print("warning: unused json keys \(items) in 'availability[_:]'")
                    }
                }
                switch items.removeValue(forKey: "domain")
                {
                case .string(let text)?: 
                    guard let domain:Domain = .init(rawValue: text)
                    else 
                    {
                        throw DecodingError.invalid(value: .string(text), key: "availability[_:].domain")
                    }
                    item.key = domain 
                case let value:
                    throw DecodingError.invalid(value: value, key: "availability[_:].domain")
                }
                let message:String?
                switch items.removeValue(forKey: "message")
                {
                case nil, .null?: 
                    message = nil
                case .string(let text)?: 
                    message = text
                case let value:
                    throw DecodingError.invalid(value: value, key: "availability[_:].message")
                }
                let renamed:String?
                switch items.removeValue(forKey: "renamed")
                {
                case nil, .null?: 
                    renamed = nil
                case .string(let text)?: 
                    renamed = text
                case let value:
                    throw DecodingError.invalid(value: value, key: "availability[_:].renamed")
                }
                
                let deprecation:Version?? 
                if let version:Version = try items.removeValue(forKey: "deprecated").map(Version.init(from:))
                {
                    deprecation = .some(version)
                }
                else 
                {
                    switch items.removeValue(forKey: "isUnconditionallyDeprecated")
                    {
                    case nil, .null?, .bool(false)?: 
                        deprecation = .none 
                    case .bool(true)?: 
                        deprecation = .some(nil)
                    case let value?:
                        throw DecodingError.invalid(value: value, key: "availability[_:].isUnconditionallyDeprecated")
                    }
                }
                // possible be both unconditionally unavailable and unconditionally deprecated
                let unavailable:Bool 
                switch items.removeValue(forKey: "isUnconditionallyUnavailable")
                {
                case nil, .null?, .bool(false)?: 
                    unavailable = false 
                case .bool(true)?: 
                    unavailable = true 
                case let value?:
                    throw DecodingError.invalid(value: value, key: "availability[_:].isUnconditionallyUnavailable")
                }
                item.value = .init(
                    unavailable: unavailable,
                    deprecated: deprecation,
                    introduced: try items.removeValue(forKey: "introduced").map(Version.init(from:)),
                    obsoleted: try items.removeValue(forKey: "obsoleted").map(Version.init(from:)), 
                    renamed: renamed,
                    message: message)
                return item 
            }
        case let value?: 
            throw DecodingError.invalid(value: value, key: "availability")
        }
        
        // decode doccomment
        let comment:String
        switch items.removeValue(forKey: "docComment")
        {
        case nil, .null?: 
            comment = ""
        case .object(var items): 
            defer 
            {
                if !items.isEmpty 
                {
                    print("warning: unused json keys \(items) in 'docComment'")
                }
            }
            switch items.removeValue(forKey: "lines")
            {
            case .array(let elements)?:
                comment = try elements.map 
                {
                    guard case .object(var items) = $0 
                    else 
                    {
                        throw DecodingError.invalid(value: $0, key: "docComment.lines[_:]")
                    }
                    defer 
                    {
                        // ignore 
                        items["range"] = nil
                        
                        if !items.isEmpty 
                        {
                            print("warning: unused json keys \(items) in 'docComment.lines[_:]'")
                        }
                    }
                    switch items.removeValue(forKey: "text")
                    {
                    case .string(let text): 
                        return text 
                    case let value: 
                        throw DecodingError.invalid(value: value, key: "docComment.lines[_:].text")
                    }
                }.joined(separator: "\n")
            case let value: 
                throw DecodingError.invalid(value: value, key: "docComment.lines")
            }
        case let value?: 
            throw DecodingError.invalid(value: value, key: "docComment")
        }
        
        return .init(
            isCanonical:    isCanonical, 
            id:             id,
            kind:           kind, 
            path:           path,
            signature:      signature, 
            declaration:    declaration, 
            extends:        extends, 
            generic:        generic, 
            availability:   availability, 
            comment:        comment)
    }
    
    static 
    func decode(constraint json:JSON) throws -> SwiftConstraint<Symbol.ID> 
    {
        typealias DecodingError = Biome.DecodingError<SwiftConstraint<Symbol.ID>>
        
        guard case .object(var items) = json 
        else 
        {
            throw DecodingError.invalid(value: json, key: nil)
        }
        defer 
        {
            if !items.isEmpty 
            {
                print("warning: unused json keys \(items)")
            }
        }
        let subject:String, 
            verb:SwiftConstraintVerb, 
            object:String
        switch items.removeValue(forKey: "lhs")
        {
        case .string(let text)?:
            subject = text 
        case let value:
            throw DecodingError.invalid(value: value, key: "lhs")
        }
        // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/JSON.cpp
        switch items.removeValue(forKey: "kind")
        {
        case .string("superclass")?:
            verb = .subclasses
        case .string("conformance")?:
            verb = .implements
        case .string("sameType")?:
            verb = .is
        case let value:
            throw DecodingError.invalid(value: value, key: "kind")
        }
        switch items.removeValue(forKey: "rhs")
        {
        case .string(let text)?:
            object = text 
        case let value:
            throw DecodingError.invalid(value: value, key: "rhs")
        }
        let id:Symbol.ID?
        switch items.removeValue(forKey: "rhsPrecise")
        {
        case .null?, nil:
            id = nil 
        case .string(let text)?:
            switch try Grammar.parse(text.utf8, as: USR.Rule<String.Index>.self)
            {
            case .natural(let natural): 
                id = natural 
            case let synthesized: 
                throw SymbolResolutionError.synthetic(resolution: synthesized)
            }
        case let value?:
            throw DecodingError.invalid(value: value, key: "rhsPrecise")
        }
        guard items.isEmpty 
        else 
        {
            throw DecodingError.unused(keys: [String].init(items.keys))
        }
        return .init(subject, verb, object, link: id)
    }
    static 
    func decode(lexeme json:JSON) throws -> (text:String, highlight:SwiftHighlight, link:Symbol.ID?)
    {
        typealias DecodingError = Biome.DecodingError<(text:String, highlight:SwiftHighlight, link:Symbol.ID?)>
        
        guard case .object(var items) = json 
        else 
        {
            throw DecodingError.invalid(value: json, key: nil)
        }
        let string:String 
        switch items.removeValue(forKey: "spelling")
        {
        case .string(let text)?:
            string = text 
        case let value:
            throw DecodingError.invalid(value: value, key: "spelling")
        }
        let id:Symbol.ID?
        switch items.removeValue(forKey: "preciseIdentifier")
        {
        case .null?, nil:
            id = nil 
        case .string(let text)?:
            switch try Grammar.parse(text.utf8, as: USR.Rule<String.Index>.self)
            {
            case .natural(let natural): 
                id = natural 
            case let synthesized: 
                throw SymbolResolutionError.synthetic(resolution: synthesized)
            }
        case let value?:
            throw DecodingError.invalid(value: value, key: "spelling")
        }
        // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/DeclarationFragmentPrinter.cpp
        let highlight:SwiftHighlight
        switch items.removeValue(forKey: "kind")
        {
        case .string("keyword")?:
            switch string 
            {
            case "init", "deinit", "subscript":
                highlight = .keywordIdentifier
            default:
                highlight = .keywordText
            }
        case .string("attribute")?:
            highlight = .attribute
        case .string("number")?:
            highlight = .number
        case .string("string")?:
            highlight = .string
        case .string("identifier")?:
            highlight = .identifier
        case .string("typeIdentifier")?:
            highlight = .type
        case .string("genericParameter")?:
            highlight = .generic
        case .string("internalParam")?:
            highlight = .parameter
        case .string("externalParam")?:
            highlight = .argument
        case .string("text")?:
            highlight = .text
        case let value?:
            throw DecodingError.invalid(value: value, key: "kind")
        case nil:
            throw DecodingError.undefined(key: "kind")
        }
        guard items.isEmpty 
        else 
        {
            throw DecodingError.unused(keys: [String].init(items.keys))
        }
        return (string, highlight, id)
    }
}

extension Biome.Version 
{
    init(from json:JSON) throws
    {
        typealias DecodingError = Biome.DecodingError<Self> 
        
        guard case .object(var items) = json 
        else 
        {
            throw DecodingError.invalid(value: json, key: nil)
        }
        defer 
        {
            if !items.isEmpty 
            {
                print("warning: unused json keys \(items) in version descriptor")
            }
        }
        switch items.removeValue(forKey: "major")
        {
        case .number(let number)?: 
            guard let major:Int = number(as: Int?.self)
            else 
            {
                throw DecodingError.invalid(value: .number(number), key: "major")
            }
            self.major = major 
        case let value: 
            throw DecodingError.invalid(value: value, key: "major")
        }
        switch items.removeValue(forKey: "minor")
        {
        case nil, .null?: 
            self.minor = nil 
        case .number(let number)?: 
            guard let minor:Int = number(as: Int?.self)
            else 
            {
                throw DecodingError.invalid(value: .number(number), key: "minor")
            }
            self.minor = minor 
        case let value: 
            throw DecodingError.invalid(value: value, key: "minor")
        }
        switch items.removeValue(forKey: "patch")
        {
        case nil, .null?:
            self.patch = nil
        case .number(let number)?: 
            guard let patch:Int = number(as: Int?.self)
            else 
            {
                throw DecodingError.invalid(value: .number(number), key: "patch")
            }
            self.patch = patch 
        case let value?: 
            throw DecodingError.invalid(value: value, key: "patch")
        }
    }
}
extension Biome.Symbol.Generic 
{
    init(from json:JSON) throws 
    {
        typealias DecodingError = Biome.DecodingError<Self>
        
        guard case .object(var items) = json 
        else 
        {
            throw DecodingError.invalid(value: json, key: nil)
        }
        defer 
        {
            if !items.isEmpty 
            {
                print("warning: unused json keys \(items)")
            }
        }
        switch items.removeValue(forKey: "name")
        {
        case .string(let text)?:
            self.name = text 
        case let value: 
            throw DecodingError.invalid(value: value, key: "name")
        }
        switch items.removeValue(forKey: "index")
        {
        case .number(let number)?:
            guard let integer:Int = number(as: Int?.self)
            else 
            {
                throw DecodingError.invalid(value: .number(number), key: "name")
            }
            self.index = integer 
        case let value: 
            throw DecodingError.invalid(value: value, key: "name")
        }
        switch items.removeValue(forKey: "depth")
        {
        case .number(let number)?:
            guard let integer:Int = number(as: Int?.self)
            else 
            {
                throw DecodingError.invalid(value: .number(number), key: "depth")
            }
            self.depth = integer 
        case let value: 
            throw DecodingError.invalid(value: value, key: "depth")
        }
    }
}
/* extension Biome.Symbol.Parameter 
{
    init(from json:JSON) throws 
    {
        typealias DecodingError = Biome.DecodingError<Self>
        
        guard case .object(var items) = json
        else 
        {
            throw DecodingError.invalid(value: json, key: nil)
        }
        defer 
        {
            if !items.isEmpty 
            {
                print("warning: unused json keys \(items)")
            }
        }
        switch items.removeValue(forKey: "name")
        {
        case .string(let text)?:
            self.label = text 
        case let value:
            throw DecodingError.invalid(value: value, key: "name")
        }
        switch items.removeValue(forKey: "internalName")
        {
        case nil, .null?:
            self.name = nil 
        case .string(let text)?:
            self.name = text 
        case let value:
            throw DecodingError.invalid(value: value, key: "internalName")
        }
        switch items.removeValue(forKey: "declarationFragments")
        {
        case .array(let elements)?: 
            self.fragment = [] // try elements.map(Biome.decode(lexeme:))
        case let value: 
            throw DecodingError.invalid(value: value, key: "declarationFragments")
        }
    } 
} */

extension Biome.Edge 
{
    init(from json:JSON) throws 
    {
        typealias DecodingError = Biome.DecodingError<Self>
         
        guard case .object(var items) = json
        else 
        {
            throw DecodingError.invalid(value: json, key: nil)
        }
        defer 
        {
            if !items.isEmpty 
            {
                print("warning: unused json keys \(items) in edge descriptor")
            }
        }
        // decode kind 
        switch items.removeValue(forKey: "kind")
        {
        case .string(let text)?:
            guard let kind:Kind = .init(rawValue: text)
            else 
            {
                throw DecodingError.invalid(value: .string(text), key: "kind")
            }
            self.kind = kind 
        case let value:
            throw DecodingError.invalid(value: value, key: "kind")
        }
        
        switch items.removeValue(forKey: "target")
        {
        case .string(let text)?:
            // synthesized symbols cannot be targets 
            switch try Grammar.parse(text.utf8, as: Biome.USR.Rule<String.Index>.self)
            {
            case .natural(let natural): 
                self.target = natural 
            case let synthesized: 
                throw Biome.SymbolResolutionError.synthetic(resolution: synthesized)
            }
        case let value:
            throw DecodingError.invalid(value: value, key: "source")
        }
        switch items.removeValue(forKey: "targetFallback")
        {
        case nil, .null?, .string(_)?:
            break // TODO: do something with this
        case let value?:
            throw DecodingError.invalid(value: value, key: "targetFallback")
        }
        
        switch items.removeValue(forKey: "source")
        {
        case .string(let text)?:
            switch try Grammar.parse(text.utf8, as: Biome.USR.Rule<String.Index>.self)
            {
            case .natural(let natural): 
                self.source = natural 
            // synthesized symbols can only be members of the type in their id
            case .synthesized(from: let generic, for: self.target):
                self.source = generic 
                guard case .member = self.kind 
                else 
                {
                    throw Biome.SymbolResolutionError.synthetic(resolution: .synthesized(from: generic, for: self.target))
                }
                self.kind = .crime 
            case let invalid:
                throw Biome.SymbolResolutionError.synthetic(resolution: invalid)
            }
        case let value:
            throw DecodingError.invalid(value: value, key: "source")
        }
        switch items.removeValue(forKey: "sourceOrigin")
        {
        case nil, .null?: 
            self.origin = nil 
        case .object(var items)?:
            defer 
            {
                if !items.isEmpty 
                {
                    print("warning: unused json keys \(items) in 'sourceOrigin'")
                }
            }
            let id:Biome.Symbol.ID, 
                name:String 
            switch items.removeValue(forKey: "identifier")
            {
            case .string(let text)?:
                // synthesized symbols cannot be documentation origins  
                switch try Grammar.parse(text.utf8, as: Biome.USR.Rule<String.Index>.self)
                {
                case .natural(let natural): 
                    id = natural 
                case let synthesized: 
                    throw Biome.SymbolResolutionError.synthetic(resolution: synthesized)
                }
            case let value:
                throw DecodingError.invalid(value: value, key: "sourceOrigin.identifier")
            }
            switch items.removeValue(forKey: "displayName")
            {
            case .string(let text)?:
                name = text
            case let value:
                throw DecodingError.invalid(value: value, key: "sourceOrigin.displayName")
            }
            self.origin = (id, name)
        case let value:
            throw DecodingError.invalid(value: value, key: "sourceOrigin")
        }
        switch items.removeValue(forKey: "swiftConstraints")
        {
        case nil, .null?: 
            self.constraints = []
        case .array(let elements)?:
            self.constraints = try elements.map(Biome.decode(constraint:))
        case let value:
            throw DecodingError.invalid(value: value, key: "swiftConstraints")
        }
    }
}
