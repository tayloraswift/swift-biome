struct StandardLibrary:Codable 
{
    struct SymbolDescription:Codable 
    {
        struct Kind:Codable 
        {
            let identifier:String 
            let displayName:String 
        }
        struct Identifier:Codable 
        {
            let precise:String 
        }
        struct TypeInfo:Codable 
        {
            struct Parameter:Codable 
            {
                let name:String 
                let depth:Int 
            }
            struct Constraint:Codable 
            {
                let kind:String 
                let lhs:String 
                let rhs:String
            }
            
            let parameters:[Parameter]?
            let constraints:[Constraint]?
        }
        
        let kind:Kind 
        let identifier:Identifier
        let path:[String]
        let typeinfo:TypeInfo? 
        
        enum CodingKeys:String, CodingKey 
        {
            case kind       = "kind"
            case identifier = "identifier"
            case path       = "pathComponents"
            case typeinfo   = "swiftGenerics"
        }
    }
    struct Relationship:Codable 
    {
        let kind:String 
        let source:String 
        let target:String 
    }
    
    let descriptions:[SymbolDescription]
    let relationships:[Relationship]
    
    enum CodingKeys:String, CodingKey 
    {
        case descriptions   = "symbols"
        case relationships  = "relationships"
    }
    
    static 
    var symbols:[Symbol.Pseudo]
    {
        guard let json:JSON = File.source(path: "standard-library-symbols/5.5-dev.json")
                .map(JSON?.init(parsing:)) ?? nil
        else 
        {
            fatalError("could not open or parse standard library json description")
        }
        guard let swift:Self = try? .init(from: JSON.Decoder.init(json: json))
        else 
        {
            fatalError("could not decode standard library json description")
        }
        
        // [precise identifier: (description, constraints, conformances)]
        typealias Descriptor = 
        (
            description:SymbolDescription, 
            constraints:Grammar.ConstraintsField?, 
            conformances:[Grammar.ConformanceField]
        )
        
        var descriptors:[String: Descriptor] = .init(uniqueKeysWithValues: swift.descriptions
            .filter 
            {
                switch $0.kind.identifier
                {
                case    "swift.enum",
                        "swift.struct",
                        "swift.class",
                        "swift.protocol",
                        "swift.associatedtype",
                        "swift.typealias":
                    return true 
                default:
                    return false
                }
            }
            .map 
            {
                let clauses:[Grammar.WhereClause] = $0.typeinfo?.constraints?.compactMap 
                {
                    let source:String 
                    switch $0.kind 
                    {
                    case "conformance": source = "\($0.lhs):\($0.rhs)"
                    case "sameType":    source = "\($0.lhs) == \($0.rhs)"
                    default:            return nil
                    }
                    
                    guard let clause:Grammar.WhereClause = .init(parsing: source)
                    else 
                    {
                        print("warning: could not parse standard library `where` clause '\(source)'")
                        return nil 
                    }
                    return clause
                } ?? []
                let descriptor:Descriptor = 
                (
                    $0,
                    clauses.isEmpty ? nil : .init(clauses: clauses), 
                    []
                )
                return ($0.identifier.precise, descriptor)
            })
        
        for relationship:Relationship in swift.relationships 
        {
            switch relationship.kind 
            {
            case "conformsTo", "inheritsFrom":  break 
            default:                            continue 
            }
            
            guard   let source:Dictionary<String, Descriptor>.Index = 
                    descriptors.index(forKey: relationship.source), 
                    let target:Dictionary<String, Descriptor>.Index = 
                    descriptors.index(forKey: relationship.target)
            else 
            {
                print("warning: could not lookup relationship pair '\(relationship.source)', '\(relationship.target)'")
                continue
            } 
            
            let conformance:Grammar.ConformanceField = .init(
                conformances:   [descriptors.values[target].description.path], 
                conditions:     [])
            descriptors.values[source].conformances.append(conformance)
        }
        
        let root:Symbol.Pseudo      = .init(kind: .module(.swift), anchor: ["Swift"], 
            fields: .init(path: ["Swift"]))
        var symbols:[Symbol.Pseudo] = [root]
        for (description, constraints, conformances):
        (
            SymbolDescription, 
            Grammar.ConstraintsField?, 
            [Grammar.ConformanceField]
        ) in descriptors.values 
        {
            let generics:[String] = (description.typeinfo?.parameters ?? [])
            .filter 
            {
                $0.depth == description.path.count - 1
            }
            .map(\.name)
            
            let path:[String] = ["Swift"] + description.path
            let anchor:[String], 
                kind:Page.Kind
            switch description.kind.identifier
            {
            case "swift.enum":
                kind    = .enum             (module: .swift, generic: !generics.isEmpty)
                anchor  = path
            case "swift.struct":
                kind    = .struct           (module: .swift, generic: !generics.isEmpty)
                anchor  = path
            case "swift.class":
                kind    = .class            (module: .swift, generic: !generics.isEmpty)
                anchor  = path
            case "swift.protocol":
                kind    = .protocol         (module: .swift)
                anchor  = path
            case "swift.typealias":
                kind    = .typealias        (module: .swift, generic: !generics.isEmpty)
                anchor = path
            case    "swift.associatedtype":
                kind    = .associatedtype   (module: .swift)
                // apple docs do not provide unique page for associatedtypes
                anchor = .init(path.dropLast())
            default:
                fatalError("unreachable")
            }
            
            symbols.append(.init(kind: kind, anchor: anchor, generics: generics, 
                fields:    .init(path: path, 
                    constraints:    constraints, 
                    conformances:   conformances)))
        }
        
        // emit builtin operator lexemes 
        for (fix, lexemes):(String, [String]) in 
        [
            (
                "prefix", 
                ["!", "~", "+", "-", "..<", "..."]
            ),
            (
                "infix", 
                [
                    "<<", ">>", "*", "/", "%", "&*", "&", "+", "-", "&+", "&-", 
                    "|", "^", "..<", "...", "??", "<", "<=", ">", ">=", "==", "!=", 
                    "===", "!==", "~=", ".==", ".!=", ".<", ".<=", ".>", ".>=", 
                    "&&", "||", "=", "*=", "/=", "%=", "+=", "-=", "<<=", ">>=", "&=", "|=", "^=",
                    // these don’t seem to be present in the apple docs, but they exist...
                    "&>>", "&>>=", "&<<", "&<<=",
                ]
            ),
            (
                "postfix", 
                ["..."]
            ),
        ]
        {
            for lexeme:String in lexemes 
            {
                symbols.append(.init(kind: .lexeme(module: .swift), 
                    anchor:  ["Swift", "swift_standard_library", "operator_declarations"], 
                    fields: .init(path: ["\(fix) operator \(lexeme)"])))
            }
        }
        
        return symbols
    }
}
