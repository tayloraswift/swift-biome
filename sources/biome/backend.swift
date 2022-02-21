import JSON

extension Biome.Graph.Symbol 
{
    init(from json:[String: JSON], in module:Biome.Graph.Module, prefix:[String]) throws 
    {
        var items:[String: JSON] = _move(json)
        defer 
        {
            if !items.isEmpty 
            {
                print("warning: unused json keys \(items) in symbol descriptor")
            }
        }
        // decode id and kind 
        let kindname:String
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
                kindname = text
            case let value:
                throw DecodingError.init(expected: String.self, in: "kind.identifier", encountered: value)
            }
        case let value:
            throw DecodingError.init(expected: [String: JSON].self, in: "kind", encountered: value)
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
                    throw DecodingError.init(expected: String.self, in: "pathComponents[_:]", encountered: $0)
                }
                return text 
            }
        case let value:
            throw DecodingError.init(expected: [JSON].self, in: "pathComponents", encountered: value)
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
            throw DecodingError.init(expected: Access.self, in: "accessLevel", encountered: value)
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
                throw DecodingError.init(expected: String.self, in: "names.title", encountered: value)
            }
            switch items.removeValue(forKey: "subHeading")
            {
            case .array(let elements)?: 
                signature = try elements.map(Language.Lexeme.init(from:))
            case let value: 
                throw DecodingError.init(expected: [JSON].self, in: "names.subHeading", encountered: value)
            }
        case let value: 
            throw DecodingError.init(expected: [String: JSON].self, in: "names", encountered: value)
        }
        // decode declaration 
        let declaration:[Language.Lexeme]
        switch items.removeValue(forKey: "declarationFragments")
        {
        case .array(let elements)?: 
            declaration = try elements.map(Language.Lexeme.init(from:))
        case let value: 
            throw DecodingError.init(expected: [JSON].self, in: "declarationFragments", encountered: value)
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
                throw DecodingError.init(expected: String.self, in: "location.uri", encountered: value)
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
                    throw DecodingError.init(expected: Int.self, in: "location.position.line", encountered: value)
                }
                switch items.removeValue(forKey: "character")
                {
                case .number(_)?: 
                    break 
                case let value: 
                    throw DecodingError.init(expected: Int.self, in: "location.position.character", encountered: value)
                }
            case let value: 
                throw DecodingError.init(expected: [String: JSON].self, in: "location.position", encountered: value)
            }
        case let value?: 
            throw DecodingError.init(expected: [String: JSON]?.self, in: "location", encountered: value)
        }
        // decode function signature
        let function:(parameters:[Parameter], returns:[Language.Lexeme])?
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
            let parameters:[Parameter], 
                returns:[Language.Lexeme]
            switch items.removeValue(forKey: "parameters")
            {
            case nil, .null?:
                parameters = []
            case .array(let elements)?: 
                parameters = try elements.map(Parameter.init(from:))
            case let value?: 
                throw DecodingError.init(expected: [JSON]?.self, in: "functionSignature.parameters", encountered: value)
            }
            switch items.removeValue(forKey: "returns")
            {
            case .array(let elements)?: 
                returns = try elements.map(Language.Lexeme.init(from:))
            case let value: 
                throw DecodingError.init(expected: [JSON].self, in: "functionSignature.returns", encountered: value)
            }
            function = (parameters, returns)
        case let value?: 
            throw DecodingError.init(expected: [String: JSON]?.self, in: "functionSignature", encountered: value)
        }
        // decode extension info
        let extends:(module:String, where:[Language.Constraint])?
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
            let module:String, 
                constraints:[Language.Constraint]
            switch items.removeValue(forKey: "extendedModule")
            {
            case .string(let text)?: 
                module = text
            case let value: 
                throw DecodingError.init(expected: String.self, in: "swiftExtension.extendedModule", encountered: value)
            }
            switch items.removeValue(forKey: "constraints")
            {
            case nil, .null?:
                constraints = []
            case .array(let elements)?: 
                constraints = try elements.map(Language.Constraint.init(from:)) 
            case let value?: 
                throw DecodingError.init(expected: [JSON]?.self, in: "swiftExtension.constraints", encountered: value)
            }
            extends = (module, constraints)
        case let value?: 
            throw DecodingError.init(expected: [String: JSON]?.self, in: "swiftExtension", encountered: value)
        }
        // decode generics info 
        let generic:(parameters:[Generic], constraints:[Language.Constraint])?
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
            let parameters:[Generic], 
                constraints:[Language.Constraint]
            switch items.removeValue(forKey: "parameters")
            {
            case nil, .null?:
                parameters = []
            case .array(let elements)?: 
                parameters = try elements.map(Generic.init(from:)) 
            case let value?: 
                throw DecodingError.init(expected: [JSON]?.self, in: "swiftGenerics.parameters", encountered: value)
            }
            switch items.removeValue(forKey: "constraints")
            {
            case nil, .null?:
                constraints = []
            case .array(let elements)?: 
                constraints = try elements.map(Language.Constraint.init(from:)) 
            case let value?: 
                throw DecodingError.init(expected: [JSON].self, in: "swiftGenerics.constraints", encountered: value)
            }
            generic = (parameters, constraints)
        case let value?: 
            throw DecodingError.init(expected: [String: JSON]?.self, in: "swiftGenerics", encountered: value)
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
                    throw DecodingError.init(expected: [String: JSON].self, in: "availability[_:]", encountered: $0)
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
                        throw DecodingError.init(expected: Domain.self, in: "availability[_:].domain", encountered: .string(text))
                    }
                    item.key = domain 
                case let value:
                    throw DecodingError.init(expected: String.self, in: "availability[_:].domain", encountered: value)
                }
                let message:String?
                switch items.removeValue(forKey: "message")
                {
                case nil, .null?: 
                    message = nil
                case .string(let text)?: 
                    message = text
                case let value:
                    throw DecodingError.init(expected: String?.self, in: "availability[_:].message", encountered: value)
                }
                let renamed:String?
                switch items.removeValue(forKey: "renamed")
                {
                case nil, .null?: 
                    renamed = nil
                case .string(let text)?: 
                    renamed = text
                case let value:
                    throw DecodingError.init(expected: String?.self, in: "availability[_:].renamed", encountered: value)
                }
                
                let deprecation:Biome.Version?? 
                if let version:Biome.Version = try items.removeValue(forKey: "deprecated").map(Biome.Version.init(from:))
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
                        throw DecodingError.init(expected: Bool?.self, in: "availability[_:].isUnconditionallyDeprecated", encountered: value)
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
                    throw DecodingError.init(expected: Bool?.self, in: "availability[_:].isUnconditionallyUnavailable", encountered: value)
                }
                item.value = .init(
                    unavailable: unavailable,
                    deprecated: deprecation,
                    introduced: try items.removeValue(forKey: "introduced").map(Biome.Version.init(from:)),
                    obsoleted: try items.removeValue(forKey: "obsoleted").map(Biome.Version.init(from:)), 
                    renamed: renamed,
                    message: message)
                return item 
            }
        case let value?: 
            throw DecodingError.init(expected: [String]?.self, in: "availability", encountered: value)
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
                        throw DecodingError.init(expected: [String: JSON].self, in: "docComment.lines[_:]", encountered: $0)
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
                        throw DecodingError.init(expected: String.self, in: "docComment.lines[_:].text", encountered: value)
                    }
                }.joined(separator: "\n")
            case let value: 
                throw DecodingError.init(expected: [JSON].self, in: "docComment.lines", encountered: value)
            }
        case let value?: 
            throw DecodingError.init(expected: [String: JSON]?.self, in: "docComment", encountered: value)
        }
        
        // downcast the kind string 
        let kind:Kind = try .init(kindname, function: function)
        let assigned:(path:Path, breadcrumbs:Biome.Graph.Breadcrumbs) = 
            Self.assign(prefix: prefix, module: module, path: path, kind: kind)
        self.init(
            kind:           kind, 
            title:          title, 
            breadcrumbs:    assigned.breadcrumbs, 
            path:           assigned.path, 
            in:             module, 
            signature:      signature, 
            declaration:    declaration, 
            extends:        extends, 
            generic:        generic, 
            availability:   [Domain: Availability].init(availability)
            {
                print("warning: multiple availability descriptors for the same domain")
                return $1
            }, 
            comment:        comment)
    }
    
    private static 
    func assign(prefix:[String], module:Biome.Graph.Module, path:[String], kind:Kind) 
        -> (path:Path, breadcrumbs:Biome.Graph.Breadcrumbs)
    {
        guard let tail:String = path.last
        else 
        {
            fatalError("empty symbol path")
        }
        // to reduce the need for disambiguation suffixes, nested types and members 
        // use different syntax: 
        // Foo.Bar.baz(qux:) -> 'foo/bar.baz(qux:)' ["foo", "bar.baz(qux:)"]
        // 
        // global variables, functions, and operators (including scoped operators) 
        // start with a slash. so it’s 'prefix/swift/withunsafepointer(to:)', 
        // not `prefix/swift.withunsafepointer(to:)`
        let unescaped:[String] 
        switch kind 
        {
        case    .module: 
            fatalError("unreachable")
        case    .associatedtype, .typealias, .enum, .struct, .class, .actor, .protocol, .global, .function, .operator:
            unescaped = prefix + module.identifier + path 
        case    .case, .initializer, .deinitializer, 
                .typeSubscript, .instanceSubscript, 
                .typeProperty, .instanceProperty, 
                .typeMethod, .instanceMethod:
            guard let scope:String = path.dropLast().last 
            else 
            {
                print("warning: member '\(path)' has no outer scope")
                unescaped = module.identifier + path 
                break 
            }
            unescaped = prefix + module.identifier + path.dropLast(2) + CollectionOfOne<String>.init("\(scope).\(tail)")
        }
        let group:String = Biome.normalize(path: unescaped)
        
        let breadcrumbs:Biome.Graph.Breadcrumbs = 
                        .init(body: [module.title] + path.dropLast(), tail: tail)
        return (.init(group: group), breadcrumbs)
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
extension Biome.Graph.Symbol.Generic 
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
extension Biome.Graph.Symbol.Parameter 
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

extension Biome.Graph.Edge 
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
            self.source = .declaration(precise: text)
        case let value:
            throw DecodingError.init(expected: String.self, in: "source", encountered: value)
        }
        switch items.removeValue(forKey: "target")
        {
        case .string(let text)?:
            self.target = .declaration(precise: text)
        case let value:
            throw DecodingError.init(expected: String.self, in: "source", encountered: value)
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
            let id:Biome.Graph.Symbol.ID, 
                name:String 
            switch items.removeValue(forKey: "identifier")
            {
            case .string(let text)?:
                id = .declaration(precise: text)
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
