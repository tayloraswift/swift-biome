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
    
    struct Context 
    {
        enum Predicate 
        {
            case alias([String])
            case inheritance([String])
            
            var alias:[String]? 
            {
                if case .alias(let alias) = self 
                {
                    return alias 
                }
                else 
                {
                    return nil
                }
            }
            var inheritance:[String]? 
            {
                if case .inheritance(let inheritance) = self 
                {
                    return inheritance 
                }
                else 
                {
                    return nil
                }
            }
        }
        
        private 
        var constraints:[[String]: [Predicate]]
        
        init() 
        {
            self.constraints = [:]
        }
        
        init(clauses:[Grammar.WhereClause])
        {
            self.constraints = [[String]: [Grammar.WhereClause]]
            .init(grouping: clauses, by: \.subject)
            .mapValues
            {
                $0.flatMap 
                {
                    (clause:Grammar.WhereClause) -> [Predicate] in 
                    switch clause.predicate 
                    {
                    case .conforms(let conformances):
                        return conformances.map(Predicate.inheritance(_:))
                    case .equals(.named(let identifiers)):
                        // strip generic parameters from named type 
                        return [Predicate.alias(identifiers.map(\.identifier))]
                    case .equals(_):
                        // cannot use tuple, function, or protocol composition types
                        return []
                    }
                }
            }
        }
        
        mutating 
        func merge(_ other:Self, where filter:([String]) -> Bool = { _ in true }) 
        {
            for (subject, predicate):([String], [Predicate]) in other.constraints
                where filter(subject)
            {
                self.constraints[subject, default: []].append(contentsOf: predicate)
            }
        }
        func merged(with other:Self) -> Self
        {
            var merged:Self = self 
            merged.merge(other)
            return merged
        }
        
        mutating 
        func pop(subject:[String]) -> [Predicate]
        {
            self.constraints.removeValue(forKey: subject) ?? []
        }
        
        subscript(subject:[String]) -> [Predicate]
        {
            self.constraints[subject, default: []]
        }
    }
    
    struct Conformer 
    {
        enum Kind 
        {
            case subclass 
            case refinement 
            
            case conformer(where:[Grammar.WhereClause]) 
            // actual conformance path (may be different due to inherited conformances)
            case inheritedConformer(actualConformance:[String])
        }
        
        let kind:Kind
        let node:Unowned<InternalNode>
        let page:Unowned<Page> 
    }
    
    let path:[String] 
    var anchor:Anchor?
    
    let inclusions:[Context.Predicate], 
        generics:Set<String>,
        context:Context // type constraints 
    
    // rivers 
    let upstream:[(path:[String], conditions:[Grammar.WhereClause])]
    // will be filled in during postprocessing
    var downstream:[Conformer] 
    var rivers:
    [(
        page    :Unowned<Page>, 
        river   :River, 
        display :Signature, 
        note    :Paragraph
    )]
    
    let kind:Kind 
    let name:String // name is not always last component of path 
    var signature:Signature
    var declaration:Declaration
    
    // preserves ordering of generic parameters
    let parameters:[String]
    
    var blurb:Paragraph
    var discussion:
    (
        parameters:[(name:String, paragraphs:[Paragraph])], 
        return:[Paragraph],
        overview:[Paragraph], 
        relationships:[(paragraph:Paragraph, context:Context)],
        specializations:[(paragraph:Paragraph, context:Context)]
    )
    
    var breadcrumbs:[(text:String, link:Link)], 
        breadcrumb:String 
    
    var topics:[Topic]
    let memberships:[(topic:String, rank:Int, order:Int)]
    // default priority
    let priority:(rank:Int, order:Int)
    
    init(parent:InternalNode?, 
        anchor:Anchor?      = nil, 
        kind:Kind, 
        generics:[String]   = [],
        aliases:[[String]]  = [],
        fields:Fields, 
        name:String, // not necessarily last `path` component
        signature:Signature, 
        declaration:Declaration)
    {
        self.path   = fields.path 
        self.anchor = anchor
        
        
        self.parameters = generics 
        
        // collect everything we know about the types mentioned in the `where` clauses
        var context:Context 
        if case .implements(let implementations)? = fields.relationships
        {
            context = .init(clauses: (fields.constraints?.clauses ?? []) + 
                implementations.flatMap(\.conditions))
        }
        else 
        {
            context = .init(clauses: fields.constraints?.clauses ?? [])
        }
        
        // collect what we know about `Self`
        var inclusions:[Context.Predicate] = 
            aliases
            .map(Context.Predicate.alias(_:))
            + 
            fields.conformances.flatMap 
            {
                $0.conditions.isEmpty ? $0.conformances : []
            }
            .map(Context.Predicate.inheritance(_:))
        // add what we know about the typealias/associatedtype 
        switch (kind, self.path.last) 
        {
        case (.associatedtype, let subject?), (.typealias, let subject?):
            inclusions.append(contentsOf: context.pop(subject: [subject]))
        default: 
            break 
        }
        
        self.inclusions = inclusions 
        
        // collect what we know about all the other types mentioned.
        let generics:Set<String> = .init(generics)
        if let outer:Page = parent?.page 
        {
            // bring in constraints from outer scope, as long as they are not 
            // shadowed by a generic in this symbol 
            context.merge(outer.context) 
            {
                if let first:String = $0.first 
                {
                    return !generics.contains(first)
                }
                else 
                {
                    return false 
                }
            }
        }
        self.context    = context 
        self.generics   = generics 
        
        // save the upstream conformances 
        self.rivers     = []
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
        
        self.memberships    = fields.memberships
        self.priority       = fields.priority
        self.topics         = fields.topics.map
        {
            .init(name: $0.name, keys: $0.keys)
        }        
        
        self.kind           = kind
        self.name           = name 
        self.signature      = signature 
        self.declaration    = declaration 
        
        self.blurb                  = fields.blurb ?? .empty
        self.discussion.overview    = fields.discussion

        self.discussion.return      = fields.callable.range?.paragraphs ?? []
        self.discussion.parameters  = fields.callable.domain.map
        {
            ($0.name, $0.paragraphs)
        }
        
        // breakcrumbs filled in during link resolution stage 
        self.breadcrumbs        = []
        self.breadcrumb         = self.path.last ?? "Documentation"
        
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
        
        self.discussion.specializations     = 
                Self.prose(specializations: fields.attributes)
    }
}

extension Page 
{
    func resolve(_ symbol:[String], in node:Node, context:Context, 
        hint:String?                                = nil, 
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
        
        let context:Context = self.context.merged(with: context)
        
        let path:ArraySlice<String> 
        var search:[[(node:Node, pages:[Page])]],
            next:Node?
        if symbol.first == "Self" 
        {
            switch self.kind 
            {
            case .enum, .struct, .class, .protocol, .extension: 
                // `Self` refers to this page, and all its extensions 
                next    = node 
                search  = [[(node, node.pages)]] + node.search(space: 
                    node.pages.flatMap(\.inclusions)
                    + 
                    context[["Self"]])
            default:
                // `Self` refers to the parent node, and all its extensions 
                guard let node:InternalNode = node.parent 
                else 
                {
                    print(warning)
                    return nil 
                }
                next    = node 
                search  = [[(node, node.pages)]] + node.search(space: 
                    node.pages.flatMap(\.inclusions)
                    + 
                    context[["Self"]])
            }
            path    = symbol.dropFirst()
        }
        else 
        {
            if let node:InternalNode = node as? InternalNode 
            {
                // include extensions 
                search  = [[(node, node.pages)]] + node.search(space: 
                    node.pages.flatMap(\.inclusions))
            }
            else 
            {
                search  = [[(node, [self])]]
            }
            next    = node
            path    = symbol[...]
        }
        
        higher:
        while let node:Node = next  
        {
            defer 
            {
                if let node:InternalNode = node.parent 
                {
                    next    = node 
                    search  = [[(node, node.pages)]] + node.search(space: 
                        node.pages.flatMap(\.inclusions))
                }
                else 
                {
                    next    = nil 
                    search  = []
                }
            }
            
            var keys:ArraySlice<String> = path
            var candidates:[Page]       = search.first?.flatMap(\.pages) ?? []
            var matched:[String]        = []
            matching:
            while let key:String = keys.popFirst() 
            {
                matched.append(key)
                for phase:[(node:Node, pages:[Page])] in search
                {
                    // HACK: only look for generics if nothing has been matched yet
                    if matched.count == 1 
                    {
                        for (node, pages):(Node, [Page]) in phase 
                        {
                            // we need to search through all outer scopes for generic 
                            // parameters, *before* looking through any inheritances. 
                            // we do not flatten deep generics, since we want the 
                            // resolved page to be the one that originally declared the 
                            // generic 
                            var next:(node:Node, pages:[Page])?     = (node, pages) 
                            while let (node, pages):(Node, [Page])  = next 
                            {
                                for page:Page in pages 
                                {
                                    if page.generics.contains(key) 
                                    {
                                        candidates  = [page]
                                        // find out what we know about this generic 
                                        // HACK :(
                                        // how do we know `node` is the right 
                                        // place to search inclusions from?
                                        search  = node.search(space: context[matched])
                                        continue matching
                                    }
                                }
                                
                                next = node.parent.map{ ($0, $0.pages) }
                            } 
                        }
                    }
                    
                    for (node, _):(Node, [Page]) in phase 
                    {
                        if let next:Node = node.children[key]
                        {
                            candidates  = next.pages 
                            search      = 
                                [[(next, next.pages)]] 
                                + 
                                next.search(space: next.pages.flatMap(\.inclusions))
                            continue matching 
                        }
                    }
                }
                if path.count < symbol.count 
                {
                    // HACK: path was relative, do not escalate 
                    break higher 
                }
                if matched.count > 1 
                {
                    // HACK: remaining path is relative, do not escalate 
                    break higher 
                }
                else 
                {
                    continue higher
                }
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
            else if path.count < symbol.count 
            {
                // path was relative, do not escalate 
                break higher 
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
            return self.resolve(["Swift"] + symbol, in: node, context: context, hint: hint, 
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
        case classProperty
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
                    .staticProperty, .classProperty, .instanceProperty:
                return .local
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
            case .classProperty:                                    return "Class Property"
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
        
        init(name:String, keys:[String]) 
        {
            self.name       = name 
            self.keys       = keys
            self.elements   = []
        }
    }
}

extension Page 
{
    static 
    func prose(specializations attributes:[Grammar.AttributeField]) 
        -> [(paragraph:Paragraph, context:Context)] 
    {
        attributes.compactMap 
        {
            guard case .specialized(let conditions) = $0 
            else 
            {
                return nil 
            }
            
            return 
                (
                    .init(parsing: "Specialization available when \(Self.prose(conditions: conditions))."), 
                    .init(clauses: conditions)
                )
        }
    }
    static 
    func prose(relationships constraints:Grammar.ConstraintsField?) 
        -> [(paragraph:Paragraph, context:Context)] 
    {
        guard let conditions:[Grammar.WhereClause] = constraints?.clauses
        else 
        {
            return []
        }
        
        return [(.init(parsing: "Available when \(Self.prose(conditions: conditions))."), .init())]
    }
    static 
    func prose(relationships fields:
        (
            relationships:Fields.Relationships?, 
            conformances:[Grammar.ConformanceField]
        )) 
        -> [(paragraph:Paragraph, context:Context)]
    {
        var paragraphs:[(paragraph:Paragraph, context:Context)] = []
        switch fields.relationships 
        {
        case .required?:
            paragraphs  = [(.init(parsing: "**Required.**"), .init())] 
        case .defaulted?:
            paragraphs  = [(.init(parsing: "**Required.** Default implementation provided."), .init())]
        case .defaultedConditionally(let conditions)?:
            paragraphs  = [(.init(parsing: "**Required.**"), .init())] + conditions.map 
            {
                (
                    .init(parsing: "Default implementation provided when \(Self.prose(conditions: $0))."), 
                    .init(clauses: $0)
                )
            }
        case .implements(let implementations)?:
            paragraphs  = []
            for implementation:Grammar.ImplementationField in implementations
            {
                if !implementation.conformances.isEmpty  
                {
                    let plural:String   = implementation.conformances.count > 1 ? "requirements" : "requirement"
                    let prose:String    = Self.prose(separator: ",", listing: implementation.conformances)
                    {
                        "[`\($0.joined(separator: "."))`]"
                    }
                    paragraphs.append(
                    (
                        .init(parsing: "Implements \(plural) in \(prose)."), 
                        .init()
                    ))
                }
                if !implementation.conditions.isEmpty 
                {
                    paragraphs.append(
                    (
                        .init(parsing: "Available when \(Self.prose(conditions: implementation.conditions))."), 
                        .init()
                    ))
                }
            }
        case nil: 
            paragraphs  = []
        }
        
        for conformance:Grammar.ConformanceField in fields.conformances 
            where !conformance.conditions.isEmpty 
        {
            let prose:String = Self.prose(separator: ",", listing: conformance.conformances)
            {
                "[`\($0.joined(separator: "."))`]"
            }
            paragraphs.append(
            (
                .init(parsing: "Conforms to \(prose) when \(Self.prose(conditions: conformance.conditions))."), 
                .init()
            ))
        }
        return paragraphs
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
    
    static 
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
    func resolveLinks(in unlinked:(declaration:Declaration, context:Context), at node:Node, 
        allowingSelfReferencingLinks:Bool = true) 
        -> Declaration
    {
        unlinked.declaration.map
        {
            switch $0 
            {
            case .identifier(let string, .unresolved(path: let path)?):
                return .identifier(string, self.resolve(path, in: node, context: unlinked.context,
                    allowingSelfReferencingLinks: allowingSelfReferencingLinks))
            case .punctuation(let string, .unresolved(path: let path)?):
                return .punctuation(string, self.resolve(path, in: node, context: unlinked.context,
                    allowingSelfReferencingLinks: allowingSelfReferencingLinks))
            default:
                return $0
            }
        }
    }
    func resolveLinks(in unlinked:(paragraph:Paragraph, context:Context), at node:Node) 
        -> Paragraph
    {
        switch unlinked.paragraph 
        {
        case .code(block: let block):
            return .code(block: .init(language: block.language, content: 
                block.content.map 
            {
                guard   case .symbol(.unresolved(path: let path))   = $0.info, 
                        let link:Link = self.resolve(path, in: node, context: unlinked.context)
                else 
                {
                    return $0
                }
                return ($0.text, .symbol(link))
            }))
        case .paragraph(let paragraph, notice: let notice):
            return .paragraph(paragraph.map 
            {
                switch $0 
                {
                case .type(let inline):
                    return .code(self.resolveLinks(in: (.init(type: inline.type), unlinked.context), at: node))
                case .symbol(let link):
                    return .code(.init 
                    {
                        Declaration.init(joining: link.paths)
                        {
                            (sublink:Paragraph.Element.SymbolLink.Path) in 
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
                                        context: unlinked.context, 
                                        hint:   $0.element.0)
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
            }, 
            notice: notice)
        }
    }
    func resolveLinks(at node:Node) 
    {
        self.declaration            = self.resolveLinks(in: (self.declaration, .init()), at: node, 
            allowingSelfReferencingLinks: false)
        self.blurb                  = self.resolveLinks(in: (self.blurb, .init()),       at: node)
        self.discussion.parameters  = self.discussion.parameters.map 
        {
            (
                $0.name, 
                $0.paragraphs.map
                { 
                    self.resolveLinks(in: ($0, .init()), at: node) 
                }
            )
        }
        self.discussion.return          = self.discussion.return.map
        {
            self.resolveLinks(in: ($0, .init()), at: node) 
        }
        self.discussion.overview        = self.discussion.overview.map
        { 
            self.resolveLinks(in: ($0, .init()), at: node) 
        }
        self.discussion.relationships   = self.discussion.relationships.map 
        {
            (self.resolveLinks(in: $0, at: node), $0.context)
        }
        self.discussion.specializations = self.discussion.specializations.map 
        {
            (self.resolveLinks(in: $0, at: node), $0.context)
        }
        
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
        case .classProperty:        return .typeProperties 
        case .instanceProperty:     return .instanceProperties
        case .associatedtype:       return .associatedtypes
        case .module(.imported):    return .dependencies 
        case .module(_), .plugin:   return nil 
        
        }
    }
}

extension Page:CustomStringConvertible 
{
    func description(indent:String) -> String 
    {
        """
        \(indent)\(self.path.joined(separator: "."))
        \(indent){
            \(indent)inclusions : \(self.inclusions)
        \(indent)}
        """
    }
    var description:String 
    {
        self.description(indent: "")
    }
}
