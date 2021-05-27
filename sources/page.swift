enum Module:Hashable
{
    case local 
    case swift 
    case imported
}

struct Unowned<Target> where Target:AnyObject
{
    unowned 
    let target:Target 
}

final 
class Page 
{
    enum Anchor 
    {
        case local(url:String, directory:[String])
        case external(path:[String])
    }
    
    struct Inclusions 
    {
        private(set)
        var aliases:[[String]],
            inheritances:[[String]]
        
        init(aliases:[[String]] = [], inheritances:[[String]] = [])
        {
            self.aliases        = aliases 
            self.inheritances   = inheritances
        }
        init(predicates:[Grammar.WherePredicate])
        {
            self.aliases        = []
            self.inheritances   = []
            self.append(predicates: predicates)
        }
        mutating 
        func append(predicates:[Grammar.WherePredicate])
        {
            for predicate:Grammar.WherePredicate in predicates 
            {
                switch predicate 
                {
                case .conforms(let conformances):
                    self.inheritances.append(contentsOf: conformances)
                case .equals(.named(let identifiers)):
                    // strip generic parameters from named type 
                    self.aliases.append(identifiers.map(\.identifier))
                case .equals(_):
                    // cannot use tuple, function, or protocol composition types
                    break 
                }
            }
        }
    }
    
    // needs to be settable, so implicit `Swift` prefixes can be added
    private(set)
    var path:[String] 
    var anchor:Anchor?
    
    let inclusions:Inclusions, 
        generics:[String: Inclusions],
        context:[[String]: Inclusions] // extra type constraints 
    
    // rivers 
    let upstream:[(path:[String], conditions:[Grammar.WhereClause])]
    // will be filled in during postprocessing
    var downstream:[(page:Unowned<Page>, river:River, display:Signature, note:[Markdown.Element])] 
    
    let kind:Kind 
    let name:String // name is not always last component of path 
    var signature:Signature
    var declaration:Declaration
    
    // preserves ordering of generic parameters
    let parameters:[String]
    
    var blurb:[Markdown.Element]
    var discussion:
    (
        parameters:[(name:String, paragraphs:[[Markdown.Element]])], 
        return:[[Markdown.Element]],
        overview:[[Markdown.Element]], 
        relationships:[[Markdown.Element]],
        specializations:[Markdown.Element]
    )
    
    var breadcrumbs:[(text:String, link:Link)], 
        breadcrumb:String 
    
    var topics:[Topic]
    let memberships:[(topic:String, rank:Int, order:Int)]
    // default priority
    let priority:(rank:Int, order:Int)
    
    init(anchor:Anchor? = nil, path:[String], 
        name:String, // not necessarily last `path` component
        kind:Kind, 
        signature:Signature, 
        declaration:Declaration, 
        generics:[String]   = [],
        aliases:[[String]]  = [],
        fields:Fields, 
        order:Int)
        throws 
    {
        self.path   = path 
        self.anchor = anchor
        
        let clauses:[Grammar.WhereClause]   
        if case .implements(let implementations)? = fields.relationships
        {
            clauses = (fields.constraints?.clauses ?? []) + 
                implementations.flatMap(\.conditions)
        }
        else 
        {
            clauses =  fields.constraints?.clauses ?? []
        }
        // collect everything we know about the types mentioned in the `where` clauses
        let constraints:[[String]: [Grammar.WherePredicate]] = [[String]: [Grammar.WhereClause]]
            .init(grouping: clauses, by: \.subject)
            .mapValues
            {
                $0.map(\.predicate)
            }
        
        // collect what we know about the generic parameters 
        var locals:Set<String>      = .init(generics)
        self.generics               = .init(uniqueKeysWithValues: locals.map 
        {
            ($0, .init(predicates: constraints[[$0], default: []]))
        })
        
        // collect what we know about `Self`
        var inclusions:Inclusions   = .init(
            aliases:        aliases, 
            inheritances:   fields.conformances.flatMap 
        {
            $0.conditions.isEmpty ? $0.conformances : []
        })
        // add what we know about the typealias/associatedtype 
        switch (kind, path.last) 
        {
        case (.associatedtype, let subject?), (.typealias, let subject?):
            inclusions.append(predicates: constraints[[subject], default: []]) 
            locals.insert(subject)
        default: 
            break 
        }
        
        self.inclusions = inclusions 
        
        // save the upstream conformances 
        self.downstream = []
        self.upstream   = fields.conformances.flatMap 
        {
            (field:Grammar.ConformanceField) in 
            field.conformances.map 
            {
                // include constraints for extension fields
                if case .extension = kind 
                {
                    return (path: $0, conditions: field.conditions + (fields.constraints?.clauses ?? []))
                } 
                else 
                {
                    return (path: $0, conditions: field.conditions)
                }
            }
        }
        
        // collect what we know about all the other types mentioned 
        self.context = constraints.filter 
        {
            if  let first:String = $0.key.first, $0.key.count == 1, 
                    locals.contains(first)
            {
                return false 
            }
            else 
            {
                return true 
            }
        }
        .mapValues(Inclusions.init(predicates:))
        
        var priority:(rank:Int, order:Int)?                     = nil 
        var memberships:[(topic:String, rank:Int, order:Int)]   = []
        for field:Grammar.TopicMembershipField in fields.memberships 
        {
            // empty rank corresponds to zero. should sort in 
            // (0:)
            // (1:)
            // (2:)
            // (3:)
            // ...
            // (-2:)
            // (-1:)
            let rank:Int = field.rank.map{ ($0 < 0 ? .max : .min) + $0 } ?? 0
            guard let topic:String = field.key 
            else 
            {
                guard priority == nil 
                else 
                {
                    throw Entrapta.Error.init("only one anonymous topic element field allowed per symbol")
                }
                priority = (rank, order)
                continue 
            }
            
            memberships.append((topic, rank, order))
        }
        self.memberships    = memberships
        self.topics         = fields.topics.map(Topic.init(_:))
        // if there is no anonymous topic element field, we want to sort 
        // the symbols alphabetically, so we set the order to max. this will 
        // put it after any topic elements with an empty membership field (`#()`), 
        // which appear in declaration-order
        self.priority       = priority ?? (0, .max)
        
        
        self.kind           = kind
        self.name           = name 
        self.signature      = signature 
        self.declaration    = declaration 
        
        self.parameters     = generics 
        
        self.blurb                  = fields.blurb ?? [] 
        self.discussion.overview    = fields.discussion

        self.discussion.return      = fields.callable.range?.paragraphs ?? []
        self.discussion.parameters  = fields.callable.domain.map
        {
            ($0.name, $0.paragraphs)
        }
        
        // breakcrumbs filled in during link resolution stage 
        self.breadcrumbs        = []
        self.breadcrumb         = path.last ?? "Documentation"
        
        // include constraints in relationships for extension fields
        if case .extension  = kind 
        {
            self.discussion.relationships   = 
                Self.prose(relationships:  fields.constraints)
        }
        else 
        {
            self.discussion.relationships   = 
                Self.prose(relationships: (fields.relationships, fields.conformances))
        }
        
        self.discussion.specializations     = Self.prose(specializations: fields.attributes)
    }
}

extension Page 
{
    func resolve(_ symbol:[String], in node:Node, hint:String? = nil, 
        allowingSelfReferencingLinks allowSelf:Bool = true,
        where predicate:(Page) -> Bool              = 
        {
            // ignore extensions by default 
            if case .extension = $0.kind 
            {
                return false 
            }
            else 
            {
                return true 
            }
        }) 
        -> Link?
    {
        var warning:String 
        {
            """
            warning: could not resolve symbol '\(symbol.joined(separator: "."))' \
            (in page '\(self.path.joined(separator: "."))')
            """
        }
        
        let path:ArraySlice<String> 
        var scope:[Page]    = [self],
            next:Node?      = node 
        if symbol.first == "Self" 
        {
            while true  
            {
                scope = scope.filter(\.kind.hasSelf)
                guard scope.isEmpty 
                else 
                {
                    break 
                }
                
                guard let parent:Node = next?.parent 
                else 
                {
                    print(warning)
                    return nil 
                }
                next    = parent 
                scope   = parent.pages 
            }
            path    = symbol.dropFirst()
        }
        else 
        {
            next    = node 
            scope   = [self]
            path    = symbol[...]
        }
        
        higher:
        while let node:Node = next  
        {
            defer 
            {
                next    = node.parent 
                scope   = node.pages 
            }
            
            var path:ArraySlice<String>                 = path
            var candidates:[Page]                       = scope 
            var search:[[(node:Node, pages:[Page])]]    = node.search(space: scope)
            var matched:[String]                        = []
            matching:
            while let key:String = path.popFirst() 
            {
                matched.append(key)
                for phase:[(node:Node, pages:[Page])] in search
                {
                    for (node, pages):(Node, [Page]) in phase 
                    {
                        // we need to search through all outer scopes for generic 
                        // parameters, *before* looking through any inheritances
                        var next:(node:Node, pages:[Page])?     = (node, pages) 
                        while let (node, pages):(Node, [Page])  = next 
                        {
                            for page:Page in pages 
                            {
                                if let inclusions:Page.Inclusions   = page.generics[key]
                                {
                                    candidates  = [page]
                                    // find out what else we know about this generic 
                                    if let context:Page.Inclusions  = self.context[matched]
                                    {
                                        search  = node.search(space: [inclusions, context])
                                    }
                                    else 
                                    {
                                        search  = node.search(space: [inclusions])
                                    }
                                    continue matching
                                }
                            }
                            
                            next = node.parent.map{ ($0, $0.pages) }
                        }
                    }
                    
                    for (node, _):(Node, [Page]) in phase 
                    {
                        if let next:Node = node.children[key]
                        {
                            candidates  = next.pages 
                            search      = next.search(space: next.pages)
                            continue matching 
                        }
                    }
                }
                continue higher
            }
            
            // only keep candidates that satisfy `predicate`
            candidates.removeAll{ !predicate($0) }
            
            let resolved:Page 
            if let candidate:Page = candidates.first 
            {
                switch (candidates.count, hint) 
                {
                case (1,            nil): 
                    // unambiguous 
                    resolved = candidate 
                case (1,            let hint?):
                    // unambiguous, extraneous hint 
                    resolved = candidate 
                    print(
                        """
                        warning: resolved link for path '\(candidate.path.joined(separator: "."))' \
                        is already unique, hint tag '#(\(hint))' is unnecessary.
                        """)
                case (let count,    let hint?): 
                    // ambiguous, use the hint to disambiguate
                    candidates.removeAll 
                    {
                        for (topic, _, _):(String, Int, Int) in $0.memberships 
                            where topic == hint 
                        {
                            return false
                        }
                        return true 
                    }
                    if let candidate:Page = candidates.first 
                    {
                        if candidates.count > 1 
                        {
                            // more than one of the hints matched 
                            print(
                                """
                                warning: resolved link for path '\(candidate.path.joined(separator: "."))' \
                                is ambigous, and \(candidates.count) of \(count) possible overloads \
                                match the provided hint '#(\(hint))'.
                                """)
                        }
                        resolved = candidate
                    }
                    else 
                    {
                        // none of the hints matched 
                        print(
                            """
                            warning: resolved link for path '\(candidate.path.joined(separator: "."))' \
                            is ambigous, but none of the \(count) candidates match the provided \
                            hint '#(\(hint))'.
                            """)
                        resolved = candidate
                    }
                    
                case (let count,    nil): 
                    // ambiguous 
                    resolved = candidate
                    print(
                        """
                        warning: resolved link for path '\(candidate.path.joined(separator: "."))' \
                        is ambigous, with \(count) possible overloads.
                        note: use a '#(_:)' hint suffix to disambiguate using a topic membership key.
                        """)
                }
            }
            else 
            {
                continue higher 
            }
            
            guard let anchor:Anchor = resolved.anchor
            else 
            {
                fatalError("page '\(resolved.path.joined(separator: "."))' has no anchor")
            }
            
            guard allowSelf || resolved !== self 
            else 
            {
                return nil
            }
            
            switch anchor 
            {
            case .local(url: let url, directory: _):
                return .resolved(url: url, module: resolved.kind.module)
            case .external(path: let path):
                return .init(builtin: path)
            }
        }
        
        // if the path does not start with the "Swift" prefix, try again with "Swift" 
        // appended to the path 
        if symbol.first != "Swift"
        {
            return self.resolve(["Swift"] + symbol, in: node, hint: hint, 
                allowingSelfReferencingLinks: allowSelf, where: predicate)
        }
        else 
        {
            print(warning)
            return nil 
        }
    }
}

extension Page 
{
    enum Kind:Hashable
    {    
        case module                    (Module) 
        case plugin 
        
        case lexeme             (module:Module)
        
        case `enum`             (module:Module, generic:Bool)
        case `struct`           (module:Module, generic:Bool)
        case `class`            (module:Module, generic:Bool)
        case `protocol`         (module:Module              )
        case `typealias`        (module:Module, generic:Bool)
        
        case `associatedtype`   (module:Module)
        case `extension`
        
        case `case`
        case functor            (generic:Bool)
        case function           (generic:Bool)
        case `operator`         (generic:Bool)
        case `subscript`        (generic:Bool) 
        case initializer        (generic:Bool)
        case instanceMethod     (generic:Bool)
        case staticMethod       (generic:Bool)
        
        case staticProperty
        case instanceProperty
        
        var module:Module 
        {
            switch self 
            {
            case    .lexeme             (module: let module            ),
                    .enum               (module: let module, generic: _),
                    .struct             (module: let module, generic: _),
                    .class              (module: let module, generic: _),
                    .protocol           (module: let module            ),
                    .typealias          (module: let module, generic: _),
                    .associatedtype     (module: let module            ), 
                    .module             (        let module            ):
                return module 
            case    .plugin,
                    .extension, .case, .functor, .function, .operator, .subscript, 
                    .initializer, .instanceMethod, .staticMethod, 
                    .staticProperty, .instanceProperty:
                return .local
            }
        }
        var hasSelf:Bool 
        {
            switch self
            {
            // `Self` refers to this page 
            case .enum, .struct, .class, .protocol: return true 
            // `Self` refers to an ancestor node 
            default:                                return false 
            }
        }
        
        var title:String 
        {
            switch self 
            {
            // should exist, but is currently unreachable
            case .lexeme    (module: .imported):                    return "Imported Lexeme"
            case .lexeme    (module: _        ):                    return "Lexeme"
            
            case .enum      (module: .imported, generic:     _):    return "Imported Enumeration"
            case .struct    (module: .imported, generic:     _):    return "Imported Structure"
            case .class     (module: .imported, generic:     _):    return "Imported Class"
            case .protocol  (module: .imported                ):    return "Imported Protocol"
            case .typealias (module: .imported, generic:     _):    return "Imported Typealias"
            
            case .enum      (module: _        , generic: false):    return "Enumeration"
            case .struct    (module: _        , generic: false):    return "Structure"
            case .class     (module: _        , generic: false):    return "Class"
            case .protocol  (module: _                        ):    return "Protocol"
            case .typealias (module: _        , generic: false):    return "Typealias"
            
            case .enum      (module: _        , generic: true ):    return "Generic Enumeration"
            case .struct    (module: _        , generic: true ):    return "Generic Structure"
            case .class     (module: _        , generic: true ):    return "Generic Class"
            case .typealias (module: _        , generic: true ):    return "Generic Typealias"
            
            // no such thing as an imported associatedtype
            case .associatedtype:                                   return "Associatedtype"
            case .plugin:                                           return "Package Plugin"
            case .case:                                             return "Enumeration Case"
            case .instanceProperty:                                 return "Instance Property"
            case .staticProperty:                                   return "Static Property"
            
            case .extension:                                        return "Extension"
            case .module(.imported):                                return "Dependency"
            case .module(_):                                        return "Module"
            
            case .function                     (generic: false):    return "Function"
            case .functor                      (generic: false):    return "Functor"
            case .initializer                  (generic: false):    return "Initializer"
            case .instanceMethod               (generic: false):    return "Instance Method"
            case .operator                     (generic: false):    return "Operator"
            case .staticMethod                 (generic: false):    return "Static Method"
            case .subscript                    (generic: false):    return "Subscript"
            
            case .function                     (generic: true ):    return "Generic Function"
            case .functor                      (generic: true ):    return "Generic Functor"
            case .initializer                  (generic: true ):    return "Generic Initializer"
            case .instanceMethod               (generic: true ):    return "Generic Instance Method"
            case .operator                     (generic: true ):    return "Generic Operator"
            case .staticMethod                 (generic: true ):    return "Generic Static Method"
            case .subscript                    (generic: true ):    return "Generic Subscript"
            }
        }
    }
    
    enum River:String, CaseIterable
    {
        case refinement     = "Refinements" 
        case conformer      = "Conforming types"
        case subclass       = "Subclasses"
    }
    
    struct Topic 
    {
        enum Builtin:String, Hashable, CaseIterable 
        {
            case dependencies       = "Dependencies"
            case cases              = "Enumeration cases"
            case associatedtypes    = "Associated types"
            case initializers       = "Initializers"
            case functors           = "Functors"
            case subscripts         = "Subscripts"
            case typeProperties     = "Type properties"
            case instanceProperties = "Instance properties"
            case typeMethods        = "Type methods"
            case instanceMethods    = "Instance methods"
            case functions          = "Functions"
            case operators          = "Operators"
            case enumerations       = "Enumerations"
            case structures         = "Structures"
            case classes            = "Classes"
            case protocols          = "Protocols"
            case typealiases        = "Typealiases"
            case extensions         = "Extensions"
            case lexemes            = "Lexemes"
        }
        
        let name:String, 
            keys:[String]
        var elements:[Unowned<Page>]
        
        init(name:String, elements:[Unowned<Page>])
        {
            self.name       = name 
            self.keys       = []
            self.elements   = elements 
        }
        
        init(_ field:Grammar.TopicField) 
        {
            self.name       = field.display 
            self.keys       = field.keys 
            self.elements   = []
        }
    }
}

extension Page 
{
    static 
    func prose(specializations attributes:[Grammar.AttributeField]) 
        -> [Markdown.Element] 
    {
        .init(parsing: attributes.compactMap 
        {
            guard case .specialized(let conditions) = $0 
            else 
            {
                return nil 
            }
            
            return "Specialization available when \(Self.prose(conditions: conditions))."
        }.joined(separator: "\\n"))
    }
    static 
    func prose(relationships constraints:Grammar.ConstraintsField?) 
        -> [[Markdown.Element]] 
    {
        guard let conditions:[Grammar.WhereClause] = constraints?.clauses
        else 
        {
            return []
        }
        
        return [.init(parsing: "Available when \(Self.prose(conditions: conditions)).")]
    }
    static 
    func prose(relationships fields:
        (
            relationships:Fields.Relationships?, 
            conformances:[Grammar.ConformanceField]
        )) 
        -> [[Markdown.Element]] 
    {
        var sentences:[String]
        switch fields.relationships 
        {
        case .required?:
            sentences       = ["**Required.**"] 
        case .defaulted?:
            sentences       = ["**Required.** Default implementation provided."]
        case .defaultedConditionally(let conditions)?:
            sentences       = ["**Required.**"] + conditions.map 
            {
                "Default implementation provided when \(Self.prose(conditions: $0))."
            }
        case .implements(let implementations)?:
            sentences       = []
            for implementation:Grammar.ImplementationField in implementations
            {
                if !implementation.conformances.isEmpty  
                {
                    let prose:String = Self.prose(separator: ",", listing: implementation.conformances)
                    {
                        "[`\($0.joined(separator: "."))`]"
                    }
                    if implementation.conformances.count > 1 
                    {
                        sentences.append("Implements requirements in \(prose).")
                    }
                    else 
                    {
                        sentences.append("Implements requirement in \(prose).")
                    }
                }
                if !implementation.conditions.isEmpty 
                {
                    sentences.append("Available when \(Self.prose(conditions: implementation.conditions)).")
                }
            }
        case nil: 
            sentences       = []
        }
        
        for conformance:Grammar.ConformanceField in fields.conformances 
            where !conformance.conditions.isEmpty 
        {
            let prose:String = Self.prose(separator: ",", listing: conformance.conformances)
            {
                "[`\($0.joined(separator: "."))`]"
            }
            sentences.append("Conforms to \(prose) when \(Self.prose(conditions: conformance.conditions)).")
        }
        
        return sentences.map([Markdown.Element].init(parsing:))
    }
    
    static 
    func prose(conditions:[Grammar.WhereClause]) -> String 
    {
        Self.prose(separator: ";", listing: conditions)
        {
            (clause:Grammar.WhereClause) in 
            switch clause.predicate
            {
            case .equals(let type):
                return "[`\(clause.subject.joined(separator: "."))`] is [[`\(type)`]]"
            case .conforms(let protocols):
                let prose:String = Self.prose(separator: ",", listing: protocols)
                {
                    "[`\($0.joined(separator: "."))`]"
                }
                return "[`\(clause.subject.joined(separator: "."))`] conforms to \(prose)"
            }
        }
    }
    
    private static 
    func prose<T>(separator:String, listing elements:[T], _ renderer:(T) -> String) 
        -> String 
    {
        let list:[String]       = elements.map(renderer)
        guard let first:String  = list.first 
        else 
        {
            fatalError("list must have at least one element")
        }
        guard let second:String = list.dropFirst().first 
        else 
        {
            return first 
        }
        guard let last:String   = list.dropFirst(2).last 
        else 
        {
            return "\(first) and \(second)"
        }
        return "\(list.dropLast().joined(separator: "\(separator) "))\(separator) and \(last)"
    }
}
extension Page 
{
    private 
    func resolveLinks(in declaration:Declaration, at node:Node, 
        allowingSelfReferencingLinks:Bool = true) 
        -> Declaration
    {
        declaration.map
        {
            switch $0 
            {
            case .identifier(let string, .unresolved(path: let path)?):
                return .identifier(string, self.resolve(path, in: node, 
                    allowingSelfReferencingLinks: allowingSelfReferencingLinks))
            case .punctuation(let string, .unresolved(path: let path)?):
                return .punctuation(string, self.resolve(path, in: node, 
                    allowingSelfReferencingLinks: allowingSelfReferencingLinks))
            default:
                return $0
            }
        }
    }
    func resolveLinks(in unlinked:[Markdown.Element], at node:Node) -> [Markdown.Element]
    {
        unlinked.map 
        {
            switch $0 
            {
            case .type(let inline):
                return .code(self.resolveLinks(in: .init(type: inline.type), at: node))
            case .symbol(let link):
                return .code(.init 
                {
                    Declaration.init(joining: link.paths)
                    {
                        (sublink:Markdown.Element.SymbolLink.Path) in 
                        // only apply the tag hint to the last component of the sublink path
                        let components:[(String?, String)] = .init(zip(
                            repeatElement(nil, count: sublink.path.count - 1) + [sublink.hint],
                            sublink.path))
                        return Declaration.init(joining: Link.scan(\.1, in: components)) 
                        {
                            switch $0.link 
                            {
                            case .unresolved(path: let path):
                                if let link:Link = self.resolve(sublink.prefix + path, in: node, 
                                    hint: $0.element.0)
                                {
                                    Declaration.identifier($0.element.1, link: link)
                                }
                                else 
                                {
                                    Declaration.identifier($0.element.1)
                                }
                            case let link:
                                Declaration.identifier($0.element.1, link: link)
                            }
                        }
                        separator: 
                        {
                            Declaration.punctuation(".")
                        }
                    }
                    separator: 
                    {
                        Declaration.punctuation(".")
                    }
                    for component:String in link.suffix 
                    {
                        Declaration.punctuation(".")
                        Declaration.identifier(component)
                    }
                })
            case let element:
                return element 
            }
        }
    }
    func resolveLinks(at node:Node) 
    {
        self.declaration            = self.resolveLinks(in: self.declaration, at: node, 
            allowingSelfReferencingLinks: false)
        self.blurb                  = self.resolveLinks(in: self.blurb, at: node)
        self.discussion.parameters  = self.discussion.parameters.map 
        {
            ($0.name, $0.paragraphs.map{ self.resolveLinks(in: $0, at: node) })
        }
        self.discussion.return          = self.discussion.return.map{   self.resolveLinks(in: $0, at: node) }
        self.discussion.overview        = self.discussion.overview.map{ self.resolveLinks(in: $0, at: node) }
        self.discussion.relationships   = self.discussion.relationships.map 
        {
            self.resolveLinks(in: $0, at: node) 
        }
        self.discussion.specializations = self.resolveLinks(in: self.discussion.specializations, at: node) 
        
        // find the documentation root node
        var root:Node           = node 
        while let parent:Node   = root.parent 
        {
            root = parent 
        }
        
        // collapse the breadcrumbs if path starts with `Swift`
        let ancestors:ArraySlice<InternalNode>
        if  self.path.first == "Swift" 
        {
            self.breadcrumb = self.path.dropFirst().joined(separator: ".")
            ancestors       = node.ancestors.prefix(1)
        }
        else 
        {
            ancestors       = node.ancestors[...]
        }
        
        self.breadcrumbs    = zip(["Documentation"] + self.path, ancestors).map 
        {
            guard case .local(url: let url, directory: _) = $0.1.page.anchor 
            else 
            {
                fatalError("missing anchor")
            }
            return ($0.0, .resolved(url: url, module: .local))
        }
    }
}

extension Page.Kind 
{
    var topic:Page.Topic.Builtin? 
    {
        if case .swift = self.module
        {
            return nil 
        }
        
        switch self 
        {
        case .enum:                 return .enumerations
        case .struct:               return .structures 
        case .class:                return .classes 
        case .protocol:             return .protocols
        case .typealias:            return .typealiases
        case .extension:            return nil 
        
        case .case:                 return .cases 
        case .initializer:          return .initializers 
        case .staticMethod:         return .typeMethods 
        case .instanceMethod:       return .instanceMethods 
        case .function:             return .functions 
        case .functor:              return .functors 
        case .lexeme:               return .lexemes 
        case .operator:             return .operators 
        case .subscript:            return .subscripts 
        case .staticProperty:       return .typeProperties
        case .instanceProperty:     return .instanceProperties
        case .associatedtype:       return .associatedtypes
        case .module(.imported):    return .dependencies 
        case .module(_), .plugin:   return nil 
        
        }
    }
}
extension Page 
{
    func markAsBuiltinScoped()
    {
        self.path = ["Swift"] + self.path
    }
}

extension Page:CustomStringConvertible 
{
    func description(indent:String) -> String 
    {
        """
        \(indent)\(self.path.joined(separator: "."))
        \(indent){
            \(indent)aliases        : \(self.inclusions.aliases)
            \(indent)inheritances   : \(self.inclusions.inheritances)
        \(indent)}
        """
    }
    var description:String 
    {
        self.description(indent: "")
    }
}
