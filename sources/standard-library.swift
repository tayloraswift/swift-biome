struct StandardLibrary:Codable 
{
    struct Symbol:Codable 
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
    
    let symbols:[Symbol]
    let relationships:[Relationship]
}

extension Node 
{
    func loadStandardLibrarySymbols() 
    {
        guard let json:JSON = File.source(path: "standard-library-symbols/5.5-dev.json")
                .map(JSON?.init(parsing:)) ?? nil
        else 
        {
            fatalError("could not open or parse standard library json description")
        }
        guard let swift:StandardLibrary = try? .init(from: JSON.Decoder.init(json: json))
        else 
        {
            fatalError("could not decode standard library json description")
        }
        
        // [precise identifier: (symbol, fields)]
        typealias Descriptor = (symbol:StandardLibrary.Symbol, fields:[Grammar.Field])
        
        var symbols:[String: Descriptor] = .init(uniqueKeysWithValues: swift.symbols
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
                
                let fields:[Grammar.Field]
                if clauses.isEmpty 
                {
                    fields = []
                }
                else 
                {
                    fields = [.constraints(.init(clauses: clauses))]
                }
                
                return ($0.identifier.precise, ($0, fields))
            })
        
        for relationship:StandardLibrary.Relationship in swift.relationships 
        {
            switch relationship.kind 
            {
            case "conformsTo", "inheritsFrom":  break 
            default:                            continue 
            }
            
            guard   let source:Dictionary<String, Descriptor>.Index = 
                    symbols.index(forKey: relationship.source), 
                    let target:Dictionary<String, Descriptor>.Index = 
                    symbols.index(forKey: relationship.target)
            else 
            {
                print("warning: could not lookup relationship pair '\(relationship.source)', '\(relationship.target)'")
                continue
            } 
            
            let field:Grammar.ConformanceField = .init(
                conformances:   [symbols.values[target].symbol.path], 
                conditions:     [])
            symbols.values[source].fields.append(.conformance(field))
        }
        
        for (symbol, fields):(StandardLibrary.Symbol, [Grammar.Field]) in symbols.values 
        {
            let generics:[String] = (symbol.typeinfo?.parameters ?? [])
            .filter 
            {
                $0.depth == symbol.path.count - 1
            }
            .map(\.name)
            
            let path:[String] = ["Swift"] + symbol.path
            let anchor:[String]
            switch symbol.kind.identifier
            {
            case    "swift.enum",
                    "swift.struct",
                    "swift.class",
                    "swift.protocol",
                    "swift.typealias":
                anchor = path
            case    "swift.associatedtype":
                // apple docs do not provide unique page for associatedtypes
                anchor = .init(path.dropLast())
            default:
                fatalError("unreachable")
            }
            
            guard   let fields:Node.Page.Fields = try? .init(fields), 
                    let page:Node.Page          = try? .init(
                        anchor:         .external(path: anchor),
                        path:           path, 
                        name:           "$builtin", 
                        label:          .swift, 
                        signature:      .empty, 
                        declaration:    .empty, 
                        generics:       generics, 
                        fields:         fields, 
                        order:          0)
            else 
            {
                fatalError("unreachable")
            }
            
            self.insert(page)
        }
    }
}
