import JSON

extension Biome.Symbol 
{
    typealias DecodingError = Biome.DecodingError<JSON, Self>
}
extension Biome.Module.ID 
{
    init(from json:JSON?) throws 
    {
        switch json
        {
        case .string("Swift")?:
            self = .swift
        case .string("_Concurrency")?:
            self = .concurrency
        case .string(let module)?:
            self = .community(module)
        default:
            throw Biome.DecodingError<JSON, Self>.init(expected: String.self, encountered: json)
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
    typealias Vertex = 
    (
        id:Symbol.ID,
        kind:Symbol.Kind, 
        title:String, 
        path:[String], 
        signature:[Language.Lexeme], 
        declaration:[Language.Lexeme], 
        extends:(module:Module.ID, where:[Language.Constraint])?,
        generic:(parameters:[Symbol.Generic], constraints:[Language.Constraint])?,
        availability:[(key:Symbol.Domain, value:Symbol.Availability)],
        comment:String
    )
    
    static 
    func decode(module json:JSON) throws -> (module:Module.ID, vertices:[Vertex], edges:[Edge])
    {
        guard   case .object(let symbolgraph)   = json, 
                case .object(let module)?       = symbolgraph["module"],
                case .array(let symbols)?       = symbolgraph["symbols"],
                case .array(let edges)?         = symbolgraph["relationships"]
        else 
        {
            throw DecodingError<JSON, Self>.init(expected: Self.self, encountered: json)
        }
        
        let decoded:(module:Module.ID, vertices:[Vertex], edges:[Edge])
        decoded.module      = try .init(from: module["name"])
        decoded.edges       = try edges.map(Edge.init(from:))
        decoded.vertices    = try symbols.map
        {
            guard case .object(let items) = $0 
            else 
            {
                throw Symbol.DecodingError.init(expected: [String: JSON].self, encountered: json)
            }
            return try Self.decode(symbol: items)
        }
        return decoded
    }
    
    static 
    func decode(symbol json:[String: JSON]) throws -> Vertex
    {
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
                id = .init(text)
            case let value:
                throw Symbol.DecodingError.init(expected: String.self, in: "identifier.precise", encountered: value)
            }
        case let value:
            throw Symbol.DecodingError.init(expected: [String: JSON].self, in: "identifier", encountered: value)
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
                    throw Symbol.DecodingError.init(expected: Symbol.Kind.self, in: "kind.identifier", encountered: .string(text))
                }
                kind = `case`
            case let value:
                throw Symbol.DecodingError.init(expected: String.self, in: "kind.identifier", encountered: value)
            }
        case let value:
            throw Symbol.DecodingError.init(expected: [String: JSON].self, in: "kind", encountered: value)
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
                    throw Symbol.DecodingError.init(expected: String.self, in: "pathComponents[_:]", encountered: $0)
                }
                return text 
            }
        case let value:
            throw Symbol.DecodingError.init(expected: [JSON].self, in: "pathComponents", encountered: value)
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
            throw Symbol.DecodingError.init(expected: Symbol.Access.self, in: "accessLevel", encountered: value)
        }
        // decode display title and signature
        let title:String, 
            signature:[Language.Lexeme]
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
            case .string(let text)?: 
                title = text 
            case let value: 
                throw Symbol.DecodingError.init(expected: String.self, in: "names.title", encountered: value)
            }
            switch items.removeValue(forKey: "subHeading")
            {
            case .array(let elements)?: 
                signature = try elements.map(Language.Lexeme.init(from:))
            case let value: 
                throw Symbol.DecodingError.init(expected: [JSON].self, in: "names.subHeading", encountered: value)
            }
        case let value: 
            throw Symbol.DecodingError.init(expected: [String: JSON].self, in: "names", encountered: value)
        }
        // decode declaration 
        let declaration:[Language.Lexeme]
        switch items.removeValue(forKey: "declarationFragments")
        {
        case .array(let elements)?: 
            declaration = try elements.map(Language.Lexeme.init(from:))
        case let value: 
            throw Symbol.DecodingError.init(expected: [JSON].self, in: "declarationFragments", encountered: value)
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
                throw Symbol.DecodingError.init(expected: String.self, in: "location.uri", encountered: value)
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
                    throw Symbol.DecodingError.init(expected: Int.self, in: "location.position.line", encountered: value)
                }
                switch items.removeValue(forKey: "character")
                {
                case .number(_)?: 
                    break 
                case let value: 
                    throw Symbol.DecodingError.init(expected: Int.self, in: "location.position.character", encountered: value)
                }
            case let value: 
                throw Symbol.DecodingError.init(expected: [String: JSON].self, in: "location.position", encountered: value)
            }
        case let value?: 
            throw Symbol.DecodingError.init(expected: [String: JSON]?.self, in: "location", encountered: value)
        }
        // decode function signature
        let function:(parameters:[Symbol.Parameter], returns:[Language.Lexeme])?
        switch items.removeValue(forKey: "functionSignature")
        {
        case nil, .null?: 
            function = nil
        case .object(var items)?: 
            defer 
            {
                if !items.isEmpty 
                {
                    print("warning: unused json keys \(items) in 'functionSignature'")
                }
            }
            let parameters:[Symbol.Parameter], 
                returns:[Language.Lexeme]
            switch items.removeValue(forKey: "parameters")
            {
            case nil, .null?:
                parameters = []
            case .array(let elements)?: 
                parameters = try elements.map(Symbol.Parameter.init(from:))
            case let value?: 
                throw Symbol.DecodingError.init(expected: [JSON]?.self, in: "functionSignature.parameters", encountered: value)
            }
            switch items.removeValue(forKey: "returns")
            {
            case .array(let elements)?: 
                returns = try elements.map(Language.Lexeme.init(from:))
            case let value: 
                throw Symbol.DecodingError.init(expected: [JSON].self, in: "functionSignature.returns", encountered: value)
            }
            function = (parameters, returns)
        case let value?: 
            throw Symbol.DecodingError.init(expected: [String: JSON]?.self, in: "functionSignature", encountered: value)
        }
        // decode extension info
        let extends:(module:Module.ID, where:[Language.Constraint])?
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
            let constraints:[Language.Constraint]
            switch items.removeValue(forKey: "constraints")
            {
            case nil, .null?:
                constraints = []
            case .array(let elements)?: 
                constraints = try elements.map(Language.Constraint.init(from:)) 
            case let value?: 
                throw Symbol.DecodingError.init(expected: [JSON]?.self, in: "swiftExtension.constraints", encountered: value)
            }
            extends = (module, constraints)
        case let value?: 
            throw Symbol.DecodingError.init(expected: [String: JSON]?.self, in: "swiftExtension", encountered: value)
        }
        // decode generics info 
        let generic:(parameters:[Symbol.Generic], constraints:[Language.Constraint])?
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
                constraints:[Language.Constraint]
            switch items.removeValue(forKey: "parameters")
            {
            case nil, .null?:
                parameters = []
            case .array(let elements)?: 
                parameters = try elements.map(Symbol.Generic.init(from:)) 
            case let value?: 
                throw Symbol.DecodingError.init(expected: [JSON]?.self, in: "swiftGenerics.parameters", encountered: value)
            }
            switch items.removeValue(forKey: "constraints")
            {
            case nil, .null?:
                constraints = []
            case .array(let elements)?: 
                constraints = try elements.map(Language.Constraint.init(from:)) 
            case let value?: 
                throw Symbol.DecodingError.init(expected: [JSON].self, in: "swiftGenerics.constraints", encountered: value)
            }
            generic = (parameters, constraints)
        case let value?: 
            throw Symbol.DecodingError.init(expected: [String: JSON]?.self, in: "swiftGenerics", encountered: value)
        }
        // decode availability
        let availability:[(key:Symbol.Domain, value:Symbol.Availability)]
        switch items.removeValue(forKey: "availability")
        {
        case nil, .null?:
            availability = []
        case .array(let elements)?: 
            availability = try elements.map 
            {
                let item:(key:Symbol.Domain, value:Symbol.Availability)
                guard case .object(var items) = $0 
                else 
                {
                    throw Symbol.DecodingError.init(expected: [String: JSON].self, in: "availability[_:]", encountered: $0)
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
                    guard let domain:Symbol.Domain = .init(rawValue: text)
                    else 
                    {
                        throw Symbol.DecodingError.init(expected: Symbol.Domain.self, in: "availability[_:].domain", encountered: .string(text))
                    }
                    item.key = domain 
                case let value:
                    throw Symbol.DecodingError.init(expected: String.self, in: "availability[_:].domain", encountered: value)
                }
                let message:String?
                switch items.removeValue(forKey: "message")
                {
                case nil, .null?: 
                    message = nil
                case .string(let text)?: 
                    message = text
                case let value:
                    throw Symbol.DecodingError.init(expected: String?.self, in: "availability[_:].message", encountered: value)
                }
                let renamed:String?
                switch items.removeValue(forKey: "renamed")
                {
                case nil, .null?: 
                    renamed = nil
                case .string(let text)?: 
                    renamed = text
                case let value:
                    throw Symbol.DecodingError.init(expected: String?.self, in: "availability[_:].renamed", encountered: value)
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
                        throw Symbol.DecodingError.init(expected: Bool?.self, in: "availability[_:].isUnconditionallyDeprecated", encountered: value)
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
                    throw Symbol.DecodingError.init(expected: Bool?.self, in: "availability[_:].isUnconditionallyUnavailable", encountered: value)
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
            throw Symbol.DecodingError.init(expected: [String]?.self, in: "availability", encountered: value)
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
                        throw Symbol.DecodingError.init(expected: [String: JSON].self, in: "docComment.lines[_:]", encountered: $0)
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
                        throw Symbol.DecodingError.init(expected: String.self, in: "docComment.lines[_:].text", encountered: value)
                    }
                }.joined(separator: "\n")
            case let value: 
                throw Symbol.DecodingError.init(expected: [JSON].self, in: "docComment.lines", encountered: value)
            }
        case let value?: 
            throw Symbol.DecodingError.init(expected: [String: JSON]?.self, in: "docComment", encountered: value)
        }
        
        return 
            (
                id:             id,
                kind:           kind, 
                title:          title, 
                path:           path,
                signature:      signature, 
                declaration:    declaration, 
                extends:        extends, 
                generic:        generic, 
                availability:   availability, 
                comment:        comment
            )
    }
}

extension Biome.Version 
{
    typealias DecodingError = Biome.DecodingError<JSON, Self> 
    
    init(from json:JSON) throws
    {
        guard case .object(var items) = json 
        else 
        {
            throw DecodingError.init(expected: [String: JSON].self, encountered: json)
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
                throw DecodingError.init(expected: Int.self, in: "major", encountered: .number(number))
            }
            self.major = major 
        case let value: 
            throw DecodingError.init(expected: JSON.Number.self, in: "major", encountered: value)
        }
        switch items.removeValue(forKey: "minor")
        {
        case nil, .null?: 
            self.minor = nil 
        case .number(let number)?: 
            guard let minor:Int = number(as: Int?.self)
            else 
            {
                throw DecodingError.init(expected: Int.self, in: "minor", encountered: .number(number))
            }
            self.minor = minor 
        case let value: 
            throw DecodingError.init(expected: JSON.Number?.self, in: "minor", encountered: value)
        }
        switch items.removeValue(forKey: "patch")
        {
        case nil, .null?:
            self.patch = nil
        case .number(let number)?: 
            guard let patch:Int = number(as: Int?.self)
            else 
            {
                throw DecodingError.init(expected: Int.self, in: "patch", encountered: .number(number))
            }
            self.patch = patch 
        case let value?: 
            throw DecodingError.init(expected: JSON.Number?.self, in: "patch", encountered: value)
        }
    }
}
extension Biome.Symbol.Generic 
{
    typealias DecodingError = Biome.DecodingError<JSON, Self>
    
    init(from json:JSON) throws 
    {
        guard case .object(var items) = json 
        else 
        {
            throw DecodingError.init(expected: [String: JSON].self, encountered: json)
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
            throw DecodingError.init(expected: String.self, in: "name", encountered: value)
        }
        switch items.removeValue(forKey: "index")
        {
        case .number(let number)?:
            guard let integer:Int = number(as: Int?.self)
            else 
            {
                throw DecodingError.init(expected: Int.self, in: "name", encountered: .number(number))
            }
            self.index = integer 
        case let value: 
            throw DecodingError.init(expected: JSON.Number.self, in: "name", encountered: value)
        }
        switch items.removeValue(forKey: "depth")
        {
        case .number(let number)?:
            guard let integer:Int = number(as: Int?.self)
            else 
            {
                throw DecodingError.init(expected: Int.self, in: "depth", encountered: .number(number))
            }
            self.depth = integer 
        case let value: 
            throw DecodingError.init(expected: JSON.Number.self, in: "depth", encountered: value)
        }
    }
}
extension Biome.Symbol.Parameter 
{
    typealias DecodingError = Biome.DecodingError<JSON, Self>
    
    init(from json:JSON) throws 
    {
        guard case .object(var items) = json
        else 
        {
            throw DecodingError.init(expected: [String: JSON].self, encountered: json)
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
            throw DecodingError.init(expected: String.self, in: "name", encountered: value)
        }
        switch items.removeValue(forKey: "internalName")
        {
        case nil, .null?:
            self.name = nil 
        case .string(let text)?:
            self.name = text 
        case let value:
            throw DecodingError.init(expected: String.self, in: "internalName", encountered: value)
        }
        switch items.removeValue(forKey: "declarationFragments")
        {
        case .array(let elements)?: 
            self.fragment = try elements.map(Language.Lexeme.init(from:))
        case let value: 
            throw DecodingError.init(expected: [JSON].self, in: "declarationFragments", encountered: value)
        }
    } 
}

extension Biome.Edge 
{
    typealias DecodingError = Biome.DecodingError<JSON, Self> 
    
    init(from json:JSON) throws 
    {
        guard case .object(var items) = json
        else 
        {
            throw DecodingError.init(expected: [String: JSON].self, encountered: json)
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
                throw DecodingError.init(expected: Kind.self, in: "kind", encountered: .string(text))
            }
            self.kind = kind 
        case let value:
            throw DecodingError.init(expected: String.self, in: "kind", encountered: value)
        }
        switch items.removeValue(forKey: "source")
        {
        case .string(let text)?:
            self.source = .init(text)
        case let value:
            throw DecodingError.init(expected: String.self, in: "source", encountered: value)
        }
        switch items.removeValue(forKey: "target")
        {
        case .string(let text)?:
            self.target = .init(text)
        case let value:
            throw DecodingError.init(expected: String.self, in: "source", encountered: value)
        }
        switch items.removeValue(forKey: "targetFallback")
        {
        case nil, .null?, .string(_)?:
            break // TODO: do something with this
        case let value?:
            throw DecodingError.init(expected: String?.self, in: "targetFallback", encountered: value)
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
                id = .init(text)
            case let value:
                throw DecodingError.init(expected: String.self, in: "sourceOrigin.identifier", encountered: value)
            }
            switch items.removeValue(forKey: "displayName")
            {
            case .string(let text)?:
                name = text
            case let value:
                throw DecodingError.init(expected: String.self, in: "sourceOrigin.displayName", encountered: value)
            }
            self.origin = (id, name)
        case let value:
            throw DecodingError.init(expected: [String: JSON]?.self, in: "sourceOrigin", encountered: value)
        }
        switch items.removeValue(forKey: "swiftConstraints")
        {
        case nil, .null?: 
            self.constraints = []
        case .array(let elements)?:
            self.constraints = try elements.map(Language.Constraint.init(from:))
        case let value:
            throw DecodingError.init(expected: [JSON]?.self, in: "swiftConstraints", encountered: value)
        }
    }
}
