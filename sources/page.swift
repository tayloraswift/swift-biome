extension Entrapta 
{
    struct Error:Swift.Error 
    {
        let message:String 
        let help:String?
        
        init(_ message:String, help:String? = nil) 
        {
            self.message    = message 
            self.help       = help
        }
    }
}

struct Unowned<Target> where Target:AnyObject
{
    unowned 
    let target:Target 
}

final 
class Node 
{    
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
        var downstream:[(page:Unowned<Page>, river:River, note:[Markdown.Element])] 
        
        let label:Label 
        let name:String // name is not always last component of path 
        var signature:Signature
        var declaration:Declaration
        
        var blurb:[Markdown.Element]
        var discussion:
        (
            parameters:[(name:String, paragraphs:[[Markdown.Element]])], 
            return:[[Markdown.Element]],
            overview:[[Markdown.Element]], 
            relationships:[Markdown.Element],
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
            label:Label, 
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
            switch (label, path.last) 
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
                    (path: $0, conditions: field.conditions)
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
            
            
            self.label          = label
            self.name           = name 
            self.signature      = signature 
            self.declaration    = declaration 
            
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
            if case .extension  = label 
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
    
    private(set) weak 
    var parent:Node?
    private(set)
    var children:[String: Node]
    
    private(set)
    var pages:[Page]
    
    init(parent:Node?) 
    {
        self.parent         = parent 
        self.children       = [:]
        self.pages          = [] 
    }
}
extension Node 
{
    private 
    func find(_ path:[String]) -> Node?
    {
        // if we can’t find anything on the first try, try again with the 
        // "Swift" prefix, to resolve a standard library symbol 
        for path:[String] in [path, ["Swift"] + path] 
        {
            var node:Node? = self 
            higher:
            while let start:Node = node 
            {
                defer 
                {
                    node = start.parent 
                }
                
                var current:Node = start  
                for component:String in path 
                {
                    guard let child:Node = current.children[component]
                    else 
                    {
                        continue higher 
                    }
                    current = child 
                }
                return current 
            }
        }
        return nil
    }
    private 
    func find(_ paths:[[String]]) -> [Node]
    {
        paths.compactMap(self.find(_:))
    }
    func search(space inclusions:[Page.Inclusions]) -> [[(node:Node, pages:[Page])]]
    {
        let spaces:[(Page.Inclusions) -> [[String]]] = 
        [
            \.aliases, 
            \.inheritances
        ]
        return spaces.map 
        {
            // recursively gather inclusions. `seen` set guards against graph cycles 
            var seen:Set<ObjectIdentifier>          = []
            var space:[(node:Node, pages:[Page])]  = []
            
            var frontier:[[String]] = inclusions.flatMap($0) 
            while !frontier.isEmpty
            {
                let nodes:[Node]    = self.find(frontier)
                frontier            = []
                for node:Node in nodes 
                    where seen.update(with: .init(node)) == nil
                {
                    frontier.append(contentsOf: node.pages.map(\.inclusions).flatMap($0))
                    space.append((node, node.pages))
                }
            }
            
            return space 
        }
    }
    func search(space pages:[Page]) -> [[(node:Node, pages:[Page])]]
    {
        [[(self, pages)]] + self.search(space: pages.map(\.inclusions))
    }
}
extension Node.Page 
{
    func resolve(_ symbol:[String], in node:Node, hint:String? = nil, 
        allowingSelfReferencingLinks allowSelf:Bool = true,
        where predicate:(Node.Page) -> Bool         = 
        {
            // ignore extensions by default 
            if case .extension = $0.label 
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
        var scope:[Node.Page]   = [self],
            next:Node?          = node 
        if symbol.first == "Self" 
        {
            while true  
            {
                scope = scope.filter 
                {
                    switch $0.label 
                    {
                    case    .importedEnumeration, .importedStructure, .importedClass, .importedProtocol,
                            .enumeration, .genericEnumeration,
                            .structure, .genericStructure,
                            .class, .genericClass,
                            .protocol, 
                            .swift(hasSelf: true): 
                        // `Self` refers to this page 
                        return true 
                    default: 
                        // `Self` refers to an ancestor node 
                        return false 
                    }
                }
                
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
            
            var path:ArraySlice<String>                     = path
            var candidates:[Node.Page]                      = scope 
            var search:[[(node:Node, pages:[Node.Page])]]   = node.search(space: scope)
            var matched:[String]                            = []
            matching:
            while let key:String = path.popFirst() 
            {
                matched.append(key)
                for phase:[(node:Node, pages:[Node.Page])] in search
                {
                    for (node, pages):(Node, [Node.Page]) in phase 
                    {
                        // we need to search through all outer scopes for generic 
                        // parameters, *before* looking through any inheritances
                        var next:(node:Node, pages:[Node.Page])?       = (node, pages) 
                        while let (node, pages):(Node, [Node.Page])    = next 
                        {
                            for page:Node.Page in pages 
                            {
                                if let inclusions:Node.Page.Inclusions = page.generics[key]
                                {
                                    candidates  = [page]
                                    // find out what else we know about this generic 
                                    if let context:Node.Page.Inclusions = self.context[matched]
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
                    
                    for (node, _):(Node, [Node.Page]) in phase 
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
            
            let resolved:Node.Page 
            if let candidate:Node.Page = candidates.first 
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
                    if let candidate:Node.Page = candidates.first 
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
                switch resolved.label 
                {
                case    .dependency, 
                        .importedEnumeration, 
                        .importedStructure, 
                        .importedClass, 
                        .importedProtocol, 
                        .importedTypealias: return .resolved(url: url, style: .imported)
                default:                    return .resolved(url: url, style: .local)
                }
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

extension Node.Page 
{
    enum Label:Hashable
    {
        case swift(hasSelf:Bool) 
        
        case module 
        case plugin 
        
        case lexeme
        
        case dependency 
        case importedEnumeration 
        case importedStructure 
        case importedClass 
        case importedProtocol 
        case importedTypealias
        
        case enumeration 
        case genericEnumeration 
        case structure 
        case genericStructure 
        case `class`
        case genericClass 
        case `protocol`
        case `typealias`
        case genericTypealias
        
        case `extension`
        
        case enumerationCase
        case functor 
        case function 
        case `operator`
        case initializer
        case staticMethod 
        case instanceMethod 
        case genericFunctor
        case genericFunction
        case genericOperator
        case genericInitializer
        case genericStaticMethod 
        case genericInstanceMethod 
        
        case staticProperty
        case instanceProperty
        case `associatedtype`
        case `subscript` 
        case genericSubscript
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
        var elements:[Unowned<Node.Page>]
        
        init(name:String, elements:[Unowned<Node.Page>])
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

extension Node.Page 
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
        -> [Markdown.Element] 
    {
        guard let conditions:[Grammar.WhereClause] = constraints?.clauses
        else 
        {
            return []
        }
        
        return .init(parsing: "Available when \(Self.prose(conditions: conditions)).")
    }
    static 
    func prose(relationships fields:
        (
            relationships:Fields.Relationships?, 
            conformances:[Grammar.ConformanceField]
        )) 
        -> [Markdown.Element] 
    {
        var sentences:[String]
        switch fields.relationships 
        {
        case .required?:
            sentences       = ["**Required.**"] 
        case .defaulted?:
            sentences       = ["**Required.**", "Default implementation provided."]
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
        
        return .init(parsing: sentences.joined(separator: "\\n"))
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
extension Node.Page 
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
        self.discussion.relationships   = self.resolveLinks(in: self.discussion.relationships, at: node) 
        self.discussion.specializations = self.resolveLinks(in: self.discussion.specializations, at: node) 
        
        // find the documentation root node
        var root:Node           = node 
        while let parent:Node   = root.parent 
        {
            root = parent 
        }
        
        // collapse the breadcrumbs if path starts with `Swift`
        let breadcrumbs:Int
        if  self.path.first == "Swift" 
        {
            self.breadcrumb = self.path.dropFirst().joined(separator: ".")
            breadcrumbs     = 1
        }
        else 
        {
            breadcrumbs     = self.path.count
        }
        
        self.breadcrumbs    = (0 ..< breadcrumbs).map 
        {
            let scan:[String]   = .init(self.path.prefix($0))
            if let text:String  = scan.last 
            {
                guard let resolved:Link = self.resolve(scan, in: node)
                else 
                {
                    fatalError("could not find page for breadcrumb '\(scan.joined(separator: "."))'") 
                }
                return (text, resolved)
            }
            else 
            {
                guard   let page:Node.Page                      = root.pages.first, 
                        case .local(url: let url, directory: _) = page.anchor 
                else 
                {
                    fatalError("could not find page for root breadcrumb")
                }
                return ("Documentation", .resolved(url: url, style: .local))
            }
        }
    }
}

extension Node.Page.Label 
{
    var topic:Node.Page.Topic.Builtin? 
    {
        switch self 
        {
        case .enumeration, .genericEnumeration, .importedEnumeration:   return .enumerations
        case .structure, .genericStructure, .importedStructure:         return .structures 
        case .class, .genericClass, .importedClass:                     return .classes 
        case .protocol, .importedProtocol:                              return .protocols
        case .typealias, .genericTypealias, .importedTypealias:         return .typealiases
        case .extension:                                                return nil 
        
        case .enumerationCase:                                          return .cases 
        case .initializer, .genericInitializer:                         return .initializers 
        case .staticMethod, .genericStaticMethod:                       return .typeMethods 
        case .instanceMethod, .genericInstanceMethod:                   return .instanceMethods 
        case .function, .genericFunction:                               return .functions 
        case .functor, .genericFunctor:                                 return .functors 
        case .lexeme:                                                   return .lexemes 
        case .operator, .genericOperator:                               return .operators 
        case .subscript, .genericSubscript:                             return .subscripts 
        case .staticProperty:                                           return .typeProperties
        case .instanceProperty:                                         return .instanceProperties
        case .associatedtype:                                           return .associatedtypes
        case .module, .plugin, .swift:                                  return nil 
        
        case .dependency:                                               return .dependencies 
        }
    }
}
extension Node.Page 
{
    func markAsBuiltinScoped()
    {
        self.path = ["Swift"] + self.path
    }
}
extension Node 
{
    var allPages:[Page] 
    {
        self.pages + self.children.values.flatMap(\.allPages)
    }
    
    func preorder(_ body:(Node) throws -> ()) rethrows 
    {
        try body(self)
        
        for child:Node in self.children.values 
        {
            try child.preorder(body)
        }
    }
    
    func postprocess(urlGenerator url:([String]) -> String)
    {
        guard self.parent == nil
        else 
        {
            fatalError("can only call \(#function) on root node")
        }
        
        // assign anchors 
        self.preorder 
        {
            (node:Node) in 
            
            for (i, page):(Int, Page) in node.pages.enumerated() 
                where page.anchor == nil // do not overwrite pre-assigned anchors
            {
                let normalized:[String] = page.path.map 
                {
                    $0.map 
                    {
                        switch $0 
                        {
                        case ".":   return "dot-"
                        case "/":   return "slash-"
                        case "~":   return "tilde-"
                        default:    return "\($0)"
                        }
                    }.joined()
                }
                
                let directory:[String]
                if let last:String = normalized.last, node.pages.count > 1
                {
                    // overloaded 
                    directory = normalized.dropLast() + ["\(i)-\(last)"]
                }
                else 
                {
                    directory = normalized 
                }
                // percent-encoding
                let escaped:[String] = directory.map 
                {
                    func hex(_ value:UInt8) -> UInt8
                    {
                        if value < 10 
                        {
                            return 0x30 + value 
                        }
                        else 
                        {
                            return 0x37 + value 
                        }
                    }
                    let bytes:[UInt8] = $0.utf8.flatMap 
                    {
                        (byte:UInt8) -> [UInt8] in 
                        switch byte 
                        {
                        ///  [0-9]          [A-Z]        [a-z]            '-'   '_'   '~'
                        case 0x30 ... 0x39, 0x41 ... 0x5a, 0x61 ... 0x7a, 0x2d, 0x5f, 0x7e:
                            return [byte] 
                        default: 
                            return [0x25, hex(byte >> 4), hex(byte & 0x0f)]
                        }
                    }
                    return .init(decoding: bytes, as: Unicode.ASCII.self)
                }
                
                page.anchor = .local(url: url(escaped), directory: directory)
            }
        }
        
        // connect rivers 
        self.preorder 
        {
            (node:Node) in 
            
            for page:Page in node.pages 
            {
                for (index, (path, conditions)):(Int, (path:[String], conditions:[Grammar.WhereClause])) in 
                    zip(page.upstream.indices, page.upstream)
                {
                    var description:String 
                    {
                        "conformance target '\(path.joined(separator: "."))'"
                    }
                    // find the upstream node and page 
                    let upstream:Page
                    if let node:Node = node.find(path)
                    {
                        // ignore extensions (we didn’t use node.resolve(_:in:...) 
                        // because that method does too much)
                        let filtered:[Page] = node.pages.filter 
                        {
                            if case .extension = $0.label 
                            {
                                return false 
                            }
                            else 
                            {
                                return true 
                            }
                        }
                        if let page:Page = filtered.first 
                        {
                            upstream = page 
                            
                            if filtered.count > 1 
                            {
                                print("warning: upstream node for \(description) has \(filtered.count) candidate pages")
                            }
                        }
                        else 
                        {
                            fatalError("upstream node for \(description) has no candidate pages")
                        }
                    }
                    else 
                    {
                        fatalError("could not find upstream node for \(description)")
                    }

                    // validate upstream target is a conformable type 
                    let river:Page.River
                    switch upstream.label
                    {
                    case .swift: 
                        continue // no point in registering conformances to builtin protocols/classes
                    case .class, .genericClass, .importedClass:
                        // validate downstream target makes sense 
                        if !conditions.isEmpty 
                        {
                            print("warning: \(description) is a class, which should not have conditions")
                        }
                        switch page.label 
                        {
                        case .protocol, .importedProtocol:
                            print("warning: \(description) is a class, which should not be refined by a protocol")
                        default:
                            break 
                        }
                        river = .subclass 
                    case .protocol, .importedProtocol:
                        switch page.label 
                        {
                        case .protocol, .importedProtocol:
                            river = .refinement 
                        default: 
                            river = .conformer
                        }
                    default:
                        print("warning: only protocols and classes can be conformed to")
                        continue 
                    }
                    
                    let note:[Markdown.Element]
                    if conditions.isEmpty 
                    {
                        note = []
                    }
                    else 
                    {
                        note = .init(parsing: "When \(Page.prose(conditions: conditions)).")
                    }
                    // resolve links *now*, since the original scope is different 
                    // from the page it will appear in 
                    upstream.downstream.append((.init(target: page), river, page.resolveLinks(in: note, at: node)))
                }
            }
        }
        
        // resolve remaining links 
        self.preorder 
        {
            (node:Node) in 
            
            for page:Page in node.pages 
            {
                if case .swift = page.label 
                {
                    continue 
                }
                
                page.resolveLinks(at: node)
                
                // while we’re at it, sort the downstream conformances 
                page.downstream.sort 
                {
                    ($0.page.target.priority.rank, $0.page.target.priority.order, $0.page.target.name) 
                    <
                    ($1.page.target.priority.rank, $1.page.target.priority.order, $1.page.target.name) 
                }
            }
        }
        
        // attach topics 
        typealias Membership = (page:Page, membership:(topic:String, rank:Int, order:Int))
        let global:[String: [Page]] = [String: [Membership]].init(grouping: 
            self.allPages.flatMap 
            {
                (page:Page) -> [Membership] in 
                var memberships:[Membership] = page.memberships.map 
                {
                    (page: page, membership: $0)
                }
                // extensions are always global, and only appear in the root page 
                if case .extension = page.label 
                {
                    memberships.append((page, ("$extensions", page.priority.rank, page.priority.order)))
                }
                return memberships
            }, by: \.membership.topic)
            .mapValues 
            {
                $0.sorted 
                {
                    ($0.membership.rank, $0.membership.order, $0.page.name) 
                    <
                    ($1.membership.rank, $1.membership.order, $1.page.name) 
                }
                .map(\.page)
            }
        self.preorder 
        {
            (node:Node) in 
            
            for page:Page in node.pages 
            {
                // keyed topics 
                var seen:Set<ObjectIdentifier> = []
                for i:Int in page.topics.indices 
                {
                    let elements:[Page] = page.topics[i].keys 
                    .flatMap
                    { 
                        global[$0, default: []] 
                    }
                    
                    // do not include this page itself (useful for "see also" groups)
                    for element:Page in elements where element !== page 
                    {
                        page.topics[i].elements.append(.init(target: element))
                        seen.insert(.init(element))
                    }
                }
                // builtin topics 
                var builtins:[Page.Topic.Builtin: [Page]] 
                if node.parent == nil 
                {
                    builtins = [.extensions: global["$extensions", default: []]]
                }
                else 
                {
                    builtins = [:]
                }
                for page:Page in node.children.values.flatMap(\.pages)
                    where !seen.contains(.init(page))
                {
                    guard let topic:Page.Topic.Builtin = page.label.topic 
                    else 
                    {
                        continue 
                    }
                    builtins[topic, default: []].append(page)
                }
                
                for topic:Page.Topic.Builtin in Page.Topic.Builtin.allCases 
                {
                    let sorted:[Page] = builtins[topic, default: []].sorted
                    {
                        ($0.priority.rank, $0.priority.order, $0.name) 
                        <
                        ($1.priority.rank, $1.priority.order, $1.name) 
                    }
                    
                    guard !sorted.isEmpty
                    else 
                    {
                        continue 
                    }
                    
                    page.topics.append(.init(name: topic.rawValue, 
                        elements: sorted.map(Unowned<Page>.init(target:))))
                }
                
                // move 'see also' to the end 
                if let i:Int = (page.topics.firstIndex{ $0.name.lowercased() == "see also" })
                {
                    let seealso:Page.Topic = page.topics.remove(at: i)
                    page.topics.append(seealso)
                }
            }
        }
    }
}

extension Node 
{
    func insert(_ page:Page)
    {
        assert(self.parent == nil)
        // check if the first path component matches a standard library symbol, to avoid 
        // generating extraneous nodes (which will mess up link resolution later)
        if  let first:String    = page.path.first, first != "Swift", 
            let _:Node          = self.find(["Swift", first])
        {
            page.markAsBuiltinScoped()
        }
        self.insert(page, level: 0)
    }
    private 
    func insert(_ page:Page, level:Int) 
    {
        guard let key:String = page.path.dropFirst(level).first 
        else 
        {
            self.pages.append(page)
            return 
        }
        
        // cannot use default dictionary subscript with Swift class 
        let child:Node 
        if let existing:Node = self.children[key]
        {
            child = existing 
        }
        else 
        {
            child = .init(parent: self)
            self.children[key] = child
        }
        child.insert(page, level: level + 1) 
    }
}
extension Node.Page:CustomStringConvertible 
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
extension Node:CustomStringConvertible 
{
    private 
    func description(indent:String) -> String 
    {
        """
        \(self.pages.count) page(s)
        \(indent){
        \(self.pages.map
        {
            $0.description(indent: indent + "    ")
        }
        .joined(separator: "\n"))
        \(indent)}\
        \(self.children.isEmpty ? "" :
        """
        
        \(indent)children:
        \(indent)[
        \(self.children.sorted
        {
            $0.key < $1.key 
        }
        .map 
        {
            """
                \(indent)['\($0.key)']: \($0.value.description(indent: indent + "    "))
            """
        }
        .joined(separator: "\n"))
        \(indent)]
        """
        )
        """
    }
    
    var description:String 
    {
        self.description(indent: "")
    }
}
