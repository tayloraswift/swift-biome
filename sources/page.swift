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
            
            init(aliases:[[String]], inheritances:[[String]])
            {
                self.aliases        = aliases 
                self.inheritances   = inheritances
            }
            init<S>(filtering clauses:[Grammar.WhereClause], subject:S)
                where S:Sequence, S.Element == String 
            {
                self.aliases        = []
                self.inheritances   = []
                self.append(filtering: clauses, subject: subject)
            }
            mutating 
            func append<S>(filtering clauses:[Grammar.WhereClause], subject:S)
                where S:Sequence, S.Element == String 
            {
                for clause:Grammar.WhereClause in clauses 
                    where clause.subject.elementsEqual(subject)
                {
                    switch clause.predicate 
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
        
        let path:[String] 
        var anchor:Anchor?
        
        let inclusions:Inclusions, 
            generics:[String: Inclusions] 
        
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
            generics:[String]  = [],
            aliases:[[String]] = [],
            fields:Fields, 
            order:Int)
            throws 
        {
            self.path   = path 
            self.anchor = anchor
            
            var inclusions:Inclusions               = .init(
                aliases:        aliases, 
                inheritances:   fields.conformances.flatMap 
            {
                $0.conditions.isEmpty ? $0.conformances : []
            })
            // add what we know about the typealias/associatedtype 
            let constraints:[Grammar.WhereClause]   = fields.constraints?.clauses ?? []
            switch label 
            {
            case    .associatedtype, .typealias:
                inclusions.append(filtering: constraints, subject: path.suffix(1)) 
            default: 
                break 
            }
            
            self.inclusions = inclusions 
            self.generics   = .init(uniqueKeysWithValues: Set.init(generics).map 
            {
                ($0, .init(filtering: constraints, subject: [$0]))
            })
            
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
            
            // include constraints in relationships for extension fields 
            if case .extension = label 
            {
                self.discussion.relationships   = Self.prose(relationships:  fields.constraints)
            }
            else 
            {
                self.discussion.relationships   = Self.prose(relationships: (fields.relationships, fields.conformances))
            }
            
            self.discussion.specializations     = Self.prose(specializations: fields.attributes)
            
            var breadcrumbs:[(String, Link)]    = [("Documentation", .unresolved(path: []))]
            +
            Link.scan(path)
            
            self.breadcrumb     = breadcrumbs.removeLast().0 
            self.breadcrumbs    = breadcrumbs
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
    func find(_ paths:[[String]]) -> [Node]
    {
        paths.compactMap 
        {
            // if we can’t find anything on the first try, try again with the 
            // "Swift" prefix, to resolve a standard library symbol 
            for path:[String] in [$0, ["Swift"] + $0] 
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
    }
    private 
    func search(space inclusions:[Page.Inclusions]) -> [(nodes:[Node], pages:[Page])]
    {
        let spaces:[(Page.Inclusions) -> [[String]]] = 
        [
            \.aliases, 
            \.inheritances
        ]
        return spaces.map 
        {
            // recursively gather inclusions. `seen` set guards against graph cycles 
            var seen:(nodes:Set<ObjectIdentifier>, pages:Set<ObjectIdentifier>) = ([], [])
            var space:(nodes:[Node], pages:[Page])                              = ([], [])
            
            var frontier:[[String]] = inclusions.flatMap($0) 
            while !frontier.isEmpty
            {
                let nodes:[Node]    = self.find(frontier)
                frontier            = []
                for node:Node in nodes 
                    where seen.nodes.update(with: .init(node)) == nil
                {
                    space.nodes.append(node)
                    for page:Page in node.pages 
                        where seen.pages.update(with: .init(page)) == nil 
                    {
                        space.pages.append(page)
                        frontier.append(contentsOf: $0(page.inclusions))
                    }
                }
            }
            
            return space 
        }
    }
    func search(space inclusions:Page.Inclusions) -> [(nodes:[Node], pages:[Page])]
    {
        self.search(space: [inclusions])
    }
    func search(space pages:[Page]) -> [(nodes:[Node], pages:[Page])]
    {
        [([self], pages)] + self.search(space: pages.map(\.inclusions))
    }
}
extension Node.Page 
{
    func resolve(_ symbol:[String], in node:Node, 
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
                            .protocol:
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
            var search:[(nodes:[Node], pages:[Node.Page])]  = node.search(space: scope)
            matching:
            while let key:String = path.popFirst() 
            {    
                for (nodes, pages):([Node], [Node.Page]) in search
                {
                    for page:Node.Page in pages 
                    {
                        if let inclusions:Node.Page.Inclusions = page.generics[key]
                        {
                            candidates  = [page]
                            search      = node.search(space: inclusions)
                            continue matching
                        }
                    }
                    for node:Node in nodes 
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
            
            candidates.removeAll{ !predicate($0) }
            
            guard   let page:Node.Page  = candidates.first, 
                    let anchor:Anchor   = page.anchor
            else 
            {
                continue higher 
            }
            
            if candidates.count > 1 
            {
                print(
                    """
                    warning: resolved link is ambigous, with \(candidates.count) candidates \
                    \(candidates.map
                    {
                        $0.path.joined(separator: ".")
                    })
                    """)
            }
            
            guard allowSelf || page !== self 
            else 
            {
                return nil
            }
            
            switch anchor 
            {
            case .local(url: let url, directory: _):
                switch page.label 
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
            return self.resolve(["Swift"] + symbol, in: node, 
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
    enum Label 
    {
        case swift 
        
        case module 
        case plugin 
        
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
    
    struct Topic 
    {
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
    private static 
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
    private static 
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
    private static 
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
                        sentences.append("Implements requirements in \(prose)")
                    }
                    else 
                    {
                        sentences.append("Implements requirement in \(prose)")
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
        
        // if more than 2 sentences, print each on its own line 
        if sentences.count > 2 
        {
            return .init(parsing: sentences.joined(separator: "\\n"))
        }
        else 
        {
            return .init(parsing: sentences.joined(separator: " "))
        }
    }
    
    private static 
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
    private 
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
                        Declaration.init(joining: Link.scan(sublink.path)) 
                        {
                            switch $0.link 
                            {
                            case .unresolved(path: let path):
                                if let link:Link = self.resolve(sublink.prefix + path, in: node)
                                {
                                    Declaration.identifier($0.element, link: link)
                                }
                                else 
                                {
                                    Declaration.identifier($0.element)
                                }
                            case let link:
                                Declaration.identifier($0.element, link: link)
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
        
        self.breadcrumbs = self.breadcrumbs.map 
        {
            switch $0.link 
            {
            case .unresolved(path: []): 
                // documentation root
                var root:Node = node 
                while let parent:Node = root.parent 
                {
                    root = parent 
                }
                guard   let page:Node.Page                      = root.pages.first, 
                        case .local(url: let url, directory: _) = page.anchor 
                else 
                {
                    fatalError("could not find page for root breadcrumb")
                }
                return ($0.text, .resolved(url: url, style: .local))
            case .unresolved(path: let path):
                // do not appleify stdlib symbols
                guard let resolved:Link = (self.resolve(path, in: node)
                {
                    if case .swift = $0.label 
                    {
                        return false 
                    }
                    else 
                    {
                        return true
                    }
                })
                else 
                {
                    fatalError("could not find page for breadcrumb '\(path.joined(separator: "."))'") 
                }
                return ($0.text, resolved)
            default:
                return $0 
            }
        }
    }
}

extension Node.Page 
{
    struct Fields
    {
        struct Callable 
        {
            let domain:[(type:Grammar.FunctionParameter, paragraphs:[[Markdown.Element]], name:String)]
            let range:(type:Grammar.SwiftType, paragraphs:[[Markdown.Element]])?
            
            var isEmpty:Bool 
            {
                self.domain.isEmpty && self.range == nil 
            }
        }
        
        enum Relationships 
        {
            case required
            case defaulted 
            case defaultedConditionally([[Grammar.WhereClause]]) 
            case implements([Grammar.ImplementationField])
        }
        
        let attributes:[Grammar.AttributeField], 
            conformances:[Grammar.ConformanceField], 
            constraints:Grammar.ConstraintsField?, 
            dispatch:Grammar.DispatchField? 
        
        let callable:Callable
        let relationships:Relationships?
        
        let paragraphs:[Grammar.ParagraphField],
            topics:[Grammar.TopicField], 
            memberships:[Grammar.TopicMembershipField]
            
        var blurb:[Markdown.Element]?
        {
            self.paragraphs.first?.elements
        }
        var discussion:[[Markdown.Element]]
        {
            self.paragraphs.dropFirst().map(\.elements)
        }
    }
}
extension Node.Page.Fields 
{
    init<S>(_ fields:S) throws where S:Sequence, S.Element == Grammar.Field 
    {
        typealias ParameterDescription = 
        (
            parameter:Grammar.ParameterField, 
            paragraphs:[Grammar.ParagraphField]
        )
        
        var attributes:[Grammar.AttributeField]             = [], 
            conformances:[Grammar.ConformanceField]         = [], 
            constraints:Grammar.ConstraintsField?           = nil, 
            dispatch:Grammar.DispatchField?                 = nil
         
        var parameters:[ParameterDescription]               = [] 
        
        var implementations:[Grammar.ImplementationField]   = [],
            requirements:[Grammar.RequirementField]         = [] 
            
        var paragraphs:[Grammar.ParagraphField]             = [],
            topics:[Grammar.TopicField]                     = [], 
            memberships:[Grammar.TopicMembershipField]      = []
            
        for field:Grammar.Field in fields
        {
            switch field 
            {
            case .attribute     (let field):
                attributes.append(field)
            case .conformance   (let field):
                conformances.append(field)
            case .implementation(let field):
                implementations.append(field)
            case .requirement   (let field):
                requirements.append(field)
            
            case .constraints   (let field):
                guard constraints == nil 
                else 
                {
                    throw Entrapta.Error.init("only one constraints field per doccomnent allowed")
                }
                constraints = field
            case .paragraph     (let field):
                if parameters.isEmpty 
                {
                    paragraphs.append(field)
                }
                else 
                {
                    parameters[parameters.endIndex - 1].paragraphs.append(field)
                }
            case .topic             (let field):
                topics.append(field)
            case .topicMembership   (let field):
                memberships.append(field)
            
            case .parameter     (let field):
                parameters.append((field, []))
            
            case .dispatch      (let field):
                guard dispatch == nil 
                else 
                {
                    throw Entrapta.Error.init("only one dispatch field per doccomnent allowed")
                }
                dispatch = field 
            
            case .subscript, .function, .property, .typealias, .type, .framework, .dependency:
                throw Entrapta.Error.init("only one header field per doccomnent allowed")
                
            case .separator:
                break
            }
        }
        
        self.attributes         = attributes
        self.conformances       = conformances
        self.constraints        = constraints
        self.dispatch           = dispatch
        
        // validate relationships 
        switch (implementations.isEmpty, requirements.isEmpty) 
        {
        case (true, true):
            self.relationships      = nil 
        case (false, true):
            self.relationships      = .implements(implementations)
        case (true, false):
            if      case .required?                     = requirements.first, 
                    requirements.count == 1 
            {
                self.relationships  = .required 
            }
            else if case .defaulted(let conditions)?    = requirements.first, 
                    requirements.count == 1, 
                    conditions.isEmpty
            {
                self.relationships  = .defaulted
            }
            else 
            {
                let conditions:[[Grammar.WhereClause]] = requirements.compactMap 
                {
                    guard case .defaulted(let conditions) = $0, !conditions.isEmpty
                    else 
                    {
                        return nil 
                    }
                    return conditions 
                }
                guard conditions.count == requirements.count 
                else 
                {
                    throw Entrapta.Error.init("if conditional `defaulted` field is present, all requirements fields must be this type")
                }
                self.relationships  = .defaultedConditionally(conditions)
            }
        case (false, false):
            throw Entrapta.Error.init("cannot have both implementations fields and requirements fields in the same doccomment")
        }
        
        // validate function fields 
        let range:(type:Grammar.SwiftType, paragraphs:[[Markdown.Element]])?
        if  let last:ParameterDescription   = parameters.last, 
            case .return                    = last.parameter.name
        {
            range = (last.parameter.parameter.type, last.paragraphs.map(\.elements))
            parameters.removeLast()
        }
        else 
        {
            range = nil 
        }
        let domain:[(type:Grammar.FunctionParameter, paragraphs:[[Markdown.Element]], name:String)] = 
            try parameters.map 
        {
            guard case .parameter(let name) = $0.parameter.name 
            else 
            {
                throw Entrapta.Error.init("return value must be the last parameter field")
            }
            return ($0.parameter.parameter, $0.paragraphs.map(\.elements), name)
        }
        
        self.callable = .init(domain: domain, range: range)
        
        self.paragraphs         = paragraphs
        self.topics             = topics 
        self.memberships        = memberships
    }
}
extension Node.Page 
{
    convenience 
    init(_ header:Grammar.FrameworkField, fields:Fields, order:Int) throws 
    {
        guard fields.relationships == nil 
        else 
        {
            throw Entrapta.Error.init("framework doccomment cannot have relationships fields")
        }
        guard fields.conformances.isEmpty 
        else 
        {
            throw Entrapta.Error.init("framework doccomment cannot have conformance fields")
        }
        guard fields.constraints == nil 
        else 
        {
            throw Entrapta.Error.init("framework doccomment cannot have a constraints field")
        }
        guard fields.dispatch == nil 
        else 
        {
            throw Entrapta.Error.init("framework doccomment cannot have a dispatch field")
        }
        guard fields.callable.isEmpty
        else 
        {
            throw Entrapta.Error.init("framework doccomment cannot have callable fields")
        }
        
        let label:Label 
        switch header.keyword 
        {
        case .module:   label = .module 
        case .plugin:   label = .plugin
        }
        try self.init(path: [], 
            name:           header.identifier, 
            label:          label, 
            signature:      .empty, 
            declaration:    .empty, 
            fields:         fields, 
            order:          order)
    }
    convenience 
    init(_ header:Grammar.DependencyField, fields:Fields, order:Int) throws
    {
        guard fields.relationships == nil 
        else 
        {
            throw Entrapta.Error.init("dependency doccomment cannot have relationships fields")
        }
        guard fields.attributes.isEmpty 
        else 
        {
            throw Entrapta.Error.init("dependency doccomment cannot have attribute fields")
        }
        guard fields.conformances.isEmpty 
        else 
        {
            throw Entrapta.Error.init("dependency doccomment cannot have conformance fields")
        }
        guard fields.constraints == nil 
        else 
        {
            throw Entrapta.Error.init("dependency doccomment cannot have a constraints field")
        }
        guard fields.dispatch == nil 
        else 
        {
            throw Entrapta.Error.init("dependency doccomment cannot have a dispatch field")
        }
        guard fields.callable.isEmpty
        else 
        {
            throw Entrapta.Error.init("dependency doccomment cannot have callable fields")
        }
        
        let name:String, 
            label:Label,
            path:[String], 
            signature:Signature, 
            declaration:Declaration
        switch header 
        {
        case .module(identifier: let identifier):
            name        = identifier 
            label       = .dependency 
            signature   = .init 
            {
                Signature.text("import")
                Signature.whitespace 
                Signature.highlight(identifier)
            }
            declaration = .init 
            {
                Declaration.keyword("import")
                Declaration.whitespace
                Declaration.identifier(identifier)
            }
            
            path = [identifier]
        case .type(keyword: let keyword, identifiers: let identifiers):
            name        = identifiers[identifiers.endIndex - 1]
            switch keyword 
            {
            case .protocol:     label = .importedProtocol
            case .enum:         label = .importedEnumeration 
            case .struct:       label = .importedStructure 
            case .class:        label = .importedClass 
            case .typealias:    label = .importedTypealias
            }
            signature   = .init 
            {
                Signature.text("\(keyword)")
                Signature.whitespace 
                Signature.init(joining: identifiers, Signature.highlight(_:))
                {
                    Signature.punctuation(".")
                }
            }
            declaration = .init 
            {
                Declaration.keyword("import")
                Declaration.whitespace
                Declaration.keyword("\(keyword)")
                Declaration.whitespace(breakable: false)
                Declaration.init(typename: identifiers.dropLast())
                Declaration.punctuation(".")
                Declaration.identifier(name)
            }
            path = identifiers 
        }
        try self.init(path: path, 
            name:           name, 
            label:          label, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            order:          order)
    }
    convenience 
    init(_ header:Grammar.SubscriptField, fields:Fields, order:Int) throws 
    {
        guard fields.conformances.isEmpty 
        else 
        {
            throw Entrapta.Error.init("subscript doccomment cannot have conformance fields")
        }
        guard fields.constraints == nil 
        else 
        {
            throw Entrapta.Error.init("constraints field in a subscript doccomment is not supported yet")
        }
        guard fields.callable.domain.count == header.labels.count
        else 
        {
            throw Entrapta.Error.init(
                "subscript has \(header.labels.count) labels, but \(fields.callable.domain.count) parameters")
        }
        guard fields.callable.range != nil
        else 
        {
            throw Entrapta.Error.init("subscript doccomment must have a return value field")
        }
        
        let name:String                             = "[\(header.labels.map{ "\($0):" }.joined())]" 
        let labels:[(name:String, variadic:Bool)]   = header.labels.map{ ($0, false) }
        let signature:Signature     = .init 
        {
            Signature.highlight("subscript")
            Signature.init(generics: header.generics)
            Signature.init(callable: fields.callable, labels: labels, throws: nil, 
                delimiters: ("[", "]"))
        }
        let declaration:Declaration = .init 
        {
            Declaration.init(attributes: fields.attributes)
            if let dispatch:Grammar.DispatchField = fields.dispatch 
            {
                Declaration.init(modifiers: dispatch)
                Declaration.whitespace 
            }
            Declaration.keyword("subscript")
            Declaration.init(generics: header.generics)
            Declaration.init(callable: fields.callable, labels: labels, throws: nil)
            {
                switch ($0, $1) 
                {
                case ("_",             "_"):    return [         "_"]
                case ("_",       let inner):    return [       inner]
                case (let outer, let inner):    return [outer, inner]
                }
            }
            if let accessors:Grammar.Accessors = header.accessors 
            {
                Declaration.whitespace 
                Declaration.init(accessors: accessors)
            }
        }
        
        try self.init(path: header.identifiers + [name], 
            name:           name, 
            label:          header.generics.isEmpty ? .subscript : .genericSubscript, 
            signature:      signature, 
            declaration:    declaration, 
            generics:       header.generics,
            fields:         fields, 
            order:          order)
    }
    convenience 
    init(_ header:Grammar.FunctionField, fields:Fields, order:Int) throws 
    {
        guard fields.conformances.isEmpty 
        else 
        {
            throw Entrapta.Error.init("function/case doccomment cannot have conformance fields")
        }
        switch (header.keyword, fields.dispatch)
        {
        case    (.case, _?), (.indirectCase, _?), 
                (.prefixFunc, _?), (.postfixFunc, _?), 
                (.staticFunc, _?), (.staticPrefixFunc, _?), (.staticPostfixFunc, _?):
            throw Entrapta.Error.init(
                """
                function/case doccomment cannot have a dispatch field if its \
                keyword is `case`, `indirect case`, `static func`, \
                `prefix func`, `postfix func`, `static prefix func`, or `static postfix func`
                """)
        default:
            break 
        }
        
        switch (header.keyword, header.identifiers.prefix)
        {
        case    (.func, []): // okay 
            break 
        case    (_,     []):
            throw Entrapta.Error.init(
                "function/case doccomment can only be declared at the toplevel if its keyword is 'func'")
        default:
            break 
        }
        switch (header.keyword, header.identifiers.tail)
        {
        case    (.`init`,               .alphanumeric("init")): // okay 
            break
        case    (.`init`,               _): 
            throw Entrapta.Error.init("initializer must have basename 'init'")
        case    (.func,                 .alphanumeric("callAsFunction")),
                (.mutatingFunc,         .alphanumeric("callAsFunction")): // okay 
            break
        case    (_,                     .alphanumeric("callAsFunction")):
            throw Entrapta.Error.init(
                "function/case doccomment can only have basename 'callAsFunction' if its keyword is `func` or `mutating func`")
        case    (.func,                 .operator(_)), 
                (.staticFunc,           .operator(_)),
                (.prefixFunc,           .operator(_)),
                (.postfixFunc,          .operator(_)),
                (.staticPrefixFunc,     .operator(_)),
                (.staticPostfixFunc,    .operator(_)): // okay 
            break 
        case    (.prefixFunc,           .alphanumeric(_)),
                (.postfixFunc,          .alphanumeric(_)),
                (.staticPrefixFunc,     .alphanumeric(_)),
                (.staticPostfixFunc,    .alphanumeric(_)): 
            throw Entrapta.Error.init(
                """
                function/case doccomment must have an operator basename if its \
                keyword is `prefix func`, `postfix func`, `static prefix func`, or `static postfix func`
                """)  
        case    (_,                     .operator(_)):
            throw Entrapta.Error.init(
                """
                function/case doccomment can only have an operator basename if its \
                keyword is `func`, `prefix func`, `postfix func`, \
                `static func`, `static prefix func`, or `static postfix func`
                """) 
        case    (_,                     .alphanumeric(_)): // okay
            break 
        }
        
        switch (header.keyword, header.labels?.count, fields.callable.domain.count)
        {
        case (.case, nil, 0), (.indirectCase, nil, 0):  break // okay
        case (.case,  _?, 0), (.indirectCase,  _?, 0): 
            throw Entrapta.Error.init(
                "uninhabited enumeration case must be written without parentheses")
        case (_, fields.callable.domain.count?, _):     break // okay 
        case (_, let labels?, let parameters):
            throw Entrapta.Error.init(
                "function/case has \(labels) labels, but \(parameters) parameters")
        case (_, nil, _):
            throw Entrapta.Error.init(
                "function/case doccomment can only omit parentheses if its keyword is `case` or `indirect case`")
        }
        
        switch 
        (
            header.keyword, 
            fields.callable.range, 
            header.throws, 
            fields.callable.domain.map(\.name) == header.labels?.map(\.name) ?? [],
            header.labels?.allSatisfy{ !$0.variadic } ?? true
        )
        {
        case (.case, _?, _, _, _), (.indirectCase, _?, _, _, _):
            throw Entrapta.Error.init(
                "function/case doccomment cannot have a return value field if its keyword is `case` or `indirect case`")
        case (.case, _, _?, _, _), (.indirectCase, _, _?, _, _):
            throw Entrapta.Error.init(
                "enumeration case cannot be marked `throws` or `rethrows`")
        case (.case, _, _, false, _), (.indirectCase, _, _, false, _):
            throw Entrapta.Error.init(
                "enumeration case cannot have different argument labels and parameter names")
        case (.case, _, _, _, false), (.indirectCase, _, _, _, false):
            throw Entrapta.Error.init(
                "enumeration case cannot have variadic arguments")
        default: 
            break // okay
        }
        
        let keywords:[String]
        switch header.keyword 
        {
        case .`init`:           keywords = []
        case .func:             keywords = ["func"]
        case .mutatingFunc:     keywords = ["mutating", "func"]
        case .prefixFunc:       keywords = ["prefix", "func"]
        case .postfixFunc:      keywords = ["postfix", "func"]
        case .staticFunc:       keywords = ["static", "func"]
        case .staticPrefixFunc: keywords = ["static", "prefix", "func"]
        case .staticPostfixFunc:keywords = ["static", "postfix", "func"]
        case .case:             keywords = ["case"]
        case .indirectCase:     keywords = ["indirect", "case"]
        }
        let label:Label 
        switch (header.keyword, header.identifiers.prefix, header.identifiers.tail, header.generics)
        {
        case    (.`init`,               _,  _,           []):   label = .initializer 
        case    (.`init`,               _,  _,           _ ):   label = .genericInitializer 
        
        case    (_,                     _, .operator(_), []), 
                (.prefixFunc,           _,  _,           []),
                (.postfixFunc,          _,  _,           []),
                (.staticPrefixFunc,     _,  _,           []),
                (.staticPostfixFunc,    _,  _,           []):   label = .operator 
        case    (_,                     _, .operator(_), _ ), 
                (.prefixFunc,           _,  _,           _ ),
                (.postfixFunc,          _,  _,           _ ),
                (.staticPrefixFunc,     _,  _,           _ ),
                (.staticPostfixFunc,    _,  _,           _ ):   label = .genericOperator 
        
        case    (.func,                 [], _,           []):   label = .function
        case    (.func,                 [], _,           _ ):   label = .genericFunction
        
        case    (_, _,  .alphanumeric("callAsFunction"), []):   label = .functor
        case    (_, _,  .alphanumeric("callAsFunction"), _ ):   label = .genericFunctor
        
        case    (.func,                 _,  _,           []):   label = .instanceMethod 
        case    (.func,                 _,  _,           _ ):   label = .genericInstanceMethod 
        
        case    (.mutatingFunc,         _,  _,           []):   label = .instanceMethod 
        case    (.mutatingFunc,         _,  _,           _ ):   label = .genericInstanceMethod 
        
        case    (.staticFunc,           _,  _,           []):   label = .staticMethod 
        case    (.staticFunc,           _,  _,           _ ):   label = .genericStaticMethod 
        
        case    (.case,                 _,  _,           []):   label = .enumerationCase
        case    (.indirectCase,         _,  _,           []):   label = .enumerationCase
        case    (.case,                 _,  _,           _ ), (.indirectCase, _, _, _):
            throw Entrapta.Error.init("enumeration case cannot have generic parameters")
        }
        
        let signature:Signature     = .init 
        {
            Signature.init(joining: keywords)
            {
                if case .alphanumeric("callAsFunction") = header.identifiers.tail 
                {
                    Signature.highlight($0)
                }
                else 
                {
                    Signature.text($0)
                }
            }
            separator: 
            {
                Signature.whitespace
            }
            switch (header.keyword, header.identifiers.tail)
            {
            case (.`init`, _):
                Signature.highlight("init")
            case (_, .alphanumeric("callAsFunction")):
                let _:Void = ()
            case (_, .alphanumeric(let basename)):
                Signature.whitespace
                Signature.highlight(basename)
            case (_, .operator(let string)):
                Signature.whitespace
                Signature.highlight(string)
                Signature.whitespace
            }
            if header.failable 
            {
                Signature.punctuation("?")
            }
            Signature.init(generics: header.generics)
            // no parentheses if uninhabited enum case 
            if let labels:[(name:String, variadic:Bool)] = header.labels
            {
                Signature.init(callable: fields.callable, labels: labels, 
                    throws: header.throws, delimiters: ("(", ")"))
            }
        }
        let declaration:Declaration = .init 
        {
            Declaration.init(attributes: fields.attributes)
            if let dispatch:Grammar.DispatchField = fields.dispatch 
            {
                Declaration.init(modifiers: dispatch)
                Declaration.whitespace 
            }
            for keyword:String in keywords 
            {
                Declaration.keyword(keyword)
                Declaration.whitespace
            }
            switch (header.keyword, header.identifiers.tail)
            {
            case (.`init`, _):
                Declaration.keyword("init")
            case (_, .alphanumeric("callAsFunction")):
                Declaration.keyword("callAsFunction")
            case (_, .alphanumeric(let basename)):
                Declaration.identifier(basename)
            case (_, .operator(let string)):
                Declaration.identifier(string)
                Declaration.whitespace(breakable: false)
            }
            if header.failable 
            {
                Declaration.punctuation("?", link: .optional)
            }
            Declaration.init(generics: header.generics)
            // no parentheses if uninhabited enum case 
            if let labels:[(name:String, variadic:Bool)] = header.labels
            {
                Declaration.init(callable: fields.callable, labels: labels, throws: header.throws)
                {
                    $0 == $1 ? [$0] : [$0, $1] 
                }
            }
            if let clauses:[Grammar.WhereClause] = fields.constraints?.clauses 
            {
                Declaration.whitespace
                Declaration.init(constraints: clauses) 
            }
        }
        
        let suffix:String? = header.labels.map 
        {
            $0.map
            { 
                "\($0.variadic && $0.name == "_" ? "" : $0.name)\($0.variadic ? "..." : ""):" 
            }.joined()
        }
        let name:String 
        switch (header.identifiers.tail, suffix)
        {
        case (.alphanumeric("callAsFunction"), let suffix?):    name =                   "(\(suffix))"
        case (let basename,                    let suffix?):    name = "\(basename.string)(\(suffix))"
        case (let basename,                    nil        ):    name =    basename.string
        }
        
        try self.init(path: header.identifiers.prefix + [name],
            name:           name, 
            label:          label, 
            signature:      signature, 
            declaration:    declaration, 
            generics:       header.generics, 
            fields:         fields, 
            order:          order)
    }
    convenience 
    init(_ header:Grammar.PropertyField, fields:Fields, order:Int) throws 
    {
        guard fields.conformances.isEmpty 
        else 
        {
            throw Entrapta.Error.init("property doccomment cannot have conformance fields", 
                help: "write property type annotations on the same line as its name.")
        }
        guard fields.constraints == nil
        else 
        {
            throw Entrapta.Error.init("property doccomment cannot have a constraints field", 
                help: "use relationships fields to specify property availability.")
        }
        guard fields.callable.isEmpty
        else 
        {
            throw Entrapta.Error.init("property doccomment cannot have callable fields")
        }
        switch (header.keyword, fields.dispatch)
        {
        case (.var, _), (_, nil):   break // okay 
        case (_, _?):
            throw Entrapta.Error.init(
                "property doccomment can only have a dispatch field if its keyword is `var`") 
        }
        switch (header.keyword, header.accessors)
        {
        case (.var, _), (.staticVar, _), (_, nil):   break // okay 
        case (_, _?):
            throw Entrapta.Error.init(
                "property doccomment can only have accessors if keyword is `var` or `static var`") 
        }
        
        let name:String = header.identifiers[header.identifiers.endIndex - 1] 
        
        let keywords:[String],
            label:Label 
        switch header.keyword
        {
        case .let:
            label       = .instanceProperty 
            keywords    = ["let"]
        case .var:
            label       = .instanceProperty 
            keywords    = ["var"]
        case .staticLet:
            label       = .staticProperty 
            keywords    = ["static", "let"]
        case .staticVar:
            label       = .staticProperty 
            keywords    = ["static", "var"]
        }
        
        let signature:Signature     = .init 
        {
            for keyword:String in keywords 
            {
                Signature.text(keyword)
                Signature.whitespace
            }
            Signature.highlight(name)
            Signature.punctuation(":")
            Signature.init(type: header.type)
        }
        let declaration:Declaration = .init 
        {
            Declaration.init(attributes: fields.attributes)
            if let dispatch:Grammar.DispatchField       = fields.dispatch 
            {
                Declaration.init(modifiers: dispatch)
                Declaration.whitespace 
            }
            for keyword:String in keywords 
            {
                Declaration.keyword(keyword)
                Declaration.whitespace
            }
            Declaration.identifier(name)
            Declaration.punctuation(":")
            Declaration.init(type: header.type)
            if let accessors:Grammar.Accessors  = header.accessors
            {
                Declaration.whitespace 
                Declaration.init(accessors: accessors)
            }
        }
        
        try self.init(path: header.identifiers, 
            name:           name, 
            label:          label, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            order:          order)
    }
    convenience 
    init(_ header:Grammar.TypealiasField, fields:Fields, order:Int) throws 
    {
        guard fields.callable.isEmpty
        else 
        {
            throw Entrapta.Error.init("typealias doccomment cannot have callable fields")
        }
        guard fields.attributes.isEmpty 
        else 
        {
            throw Entrapta.Error.init("typealias doccomment cannot have attribute fields")
        }
        guard fields.conformances.isEmpty 
        else 
        {
            throw Entrapta.Error.init("typealias doccomment cannot have conformance fields")
        }
        guard fields.dispatch == nil 
        else 
        {
            throw Entrapta.Error.init("typealias doccomment cannot have a dispatch field")
        }
        
        let name:String = header.identifiers.joined(separator: ".")
        let signature:Signature     = .init 
        {
            Signature.text("typealias")
            Signature.whitespace
            Signature.init(joining: header.identifiers, Signature.highlight(_:))
            {
                Signature.punctuation(".")
            }
            Signature.init(generics: header.generics)
        }
        let declaration:Declaration = .init 
        {
            Declaration.keyword("typealias")
            Declaration.whitespace
            Declaration.identifier(header.identifiers[header.identifiers.endIndex - 1])
            Declaration.init(generics: header.generics)
            Declaration.whitespace(breakable: false)
            Declaration.punctuation("=")
            Declaration.whitespace
            Declaration.init(type: header.target)
            if let clauses:[Grammar.WhereClause]        = fields.constraints?.clauses 
            {
                Declaration.whitespace
                Declaration.init(constraints: clauses) 
            }
        }
        
        let aliased:[[String]]
        switch header.target 
        {
        case .named(let identifiers):
            // strip generic parameters from named type 
            aliased = [identifiers.map(\.identifier)]
        default: 
            aliased = []
        }
        
        try self.init(path: header.identifiers, 
            name:           name, 
            label:          .typealias, 
            signature:      signature, 
            declaration:    declaration, 
            generics:       header.generics,
            aliases:        aliased,
            fields:         fields, 
            order:          order)
    }
    convenience 
    init(_ header:Grammar.TypeField, fields:Fields, order:Int) throws 
    {
        guard fields.callable.isEmpty
        else 
        {
            throw Entrapta.Error.init("type doccomment cannot have callable fields")
        }
        // this restriction really isn’t necessary, and should be removed eventually 
        if case .associatedtype = header.keyword, !fields.conformances.isEmpty
        {
            throw Entrapta.Error.init("associatedtype cannot have conformance fields", 
                help: "write associatedtype constraints in a constraints field.")
        }
        switch 
        (
            header.keyword, 
            fields.dispatch, 
            fields.dispatch?.keywords.contains(.override) ?? false
        )
        {
        case (_,      nil,   _), (.class, _?, false): break // okay 
        case (.class, _?, true):
            throw Entrapta.Error.init("type doccomment cannot have a dispatch field with an `override` modifier")
        case (_,      _?,    _):
            throw Entrapta.Error.init("type doccomment can only have a dispatch field if its keyword is `class`")
        }
        
        let name:String = header.identifiers.joined(separator: ".")
        
        let label:Label
        switch (header.keyword, header.generics) 
        {
        case (.extension, []):
            label   = .extension 
        case (.extension, _):
            throw Entrapta.Error.init("extension cannot have generic parameters")
        
        case (.associatedtype, []):
            label   = .associatedtype 
        case (.associatedtype, _):
            throw Entrapta.Error.init("associatedtype cannot have generic parameters")
        
        case (.protocol, []):
            label   = .protocol 
        case (.protocol, _):
            throw Entrapta.Error.init("protocol cannot have generic parameters")
        
        case (.class, []):
            label   = .class 
        case (.class, _):
            label   = .genericClass 
        
        case (.struct, []):
            label   = .structure 
        case (.struct, _):
            label   = .genericStructure 
        
        case (.enum, []):
            label   = .enumeration
        case (.enum, _):
            label   = .genericEnumeration
        }
        
        // only put universal conformances in the declaration 
        let conformances:[[[String]]] = fields.conformances.compactMap 
        {
            $0.conditions.isEmpty ? $0.conformances : nil 
        }
        if  case .extension = header.keyword, 
            conformances.count != fields.conformances.count
        {
            throw Entrapta.Error.init("extension cannot have conditional conformances", 
                help: 
                """
                write the conformances as unconditional conformances, and use a \
                constraints field to specify their conditions.
                """)
        }
        
        let signature:Signature     = .init 
        {
            Signature.text("\(header.keyword)")
            Signature.whitespace
            Signature.init(joining: header.identifiers, Signature.highlight(_:))
            {
                Signature.punctuation(".")
            }
            Signature.init(generics: header.generics)
            // include conformances in signature, if extension 
            if case .extension = header.keyword, !conformances.isEmpty
            {
                Signature.punctuation(":") 
                Signature.init(joining: conformances) 
                {
                    Signature.init(joining: $0)
                    {
                        Signature.init(joining: $0, Signature.text(_:))
                        {
                            Signature.punctuation(".") 
                        }
                    }
                    separator:
                    {
                        Signature.whitespace
                        Signature.punctuation("&") 
                        Signature.whitespace
                    }
                }
                separator:
                {
                    Signature.punctuation(",") 
                    Signature.whitespace
                }
            }
        }
        let declaration:Declaration = .init 
        {
            Declaration.init(attributes: fields.attributes)
            if let dispatch:Grammar.DispatchField       = fields.dispatch 
            {
                Declaration.init(modifiers: dispatch)
                Declaration.whitespace 
            }
            Declaration.keyword("\(header.keyword)")
            Declaration.whitespace
            if      case .extension                     = header.keyword 
            {
                Declaration.init(typename: header.identifiers)
            }
            else if let last:String                     = header.identifiers.last  
            {
                Declaration.identifier(last)
            }
            Declaration.init(generics: header.generics)
            if !conformances.isEmpty 
            {
                Declaration.punctuation(":") 
                Declaration.init(joining: conformances) 
                {
                    Declaration.init(joining: $0, Declaration.init(typename:))
                    {
                        Declaration.whitespace(breakable: false)
                        Declaration.punctuation("&") 
                        Declaration.whitespace(breakable: false)
                    }
                }
                separator:
                {
                    Declaration.punctuation(",") 
                    Declaration.whitespace
                }
            }
            if let clauses:[Grammar.WhereClause]        = fields.constraints?.clauses 
            {
                Declaration.whitespace
                Declaration.init(constraints: clauses) 
            }
        }
        
        try self.init(path: header.identifiers, 
            name:           name, 
            label:          label, 
            signature:      signature, 
            declaration:    declaration, 
            generics:       header.generics,
            fields:         fields, 
            order:          order)
    }
}

extension Node 
{
    var preorder:[Node] 
    {
        [self] + self.children.values.flatMap(\.preorder)
    }
    
    func assignAnchors(_ url:([String]) -> String)
    {
        for (i, page):(Int, Page) in self.pages.enumerated() 
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
                    default :   return "\($0)"
                    }
                }.joined()
            }
            
            let directory:[String]
            if let last:String = normalized.last, self.pages.count > 1
            {
                // overloaded 
                directory = normalized.dropLast() + ["\(i)-\(last)"]
            }
            else 
            {
                directory = normalized 
            }
            
            page.anchor = .local(url: url(directory), directory: directory)
        }
        
        for child:Node in self.children.values 
        {
            child.assignAnchors(url)
        }
    }
    func resolveLinks() 
    {
        for page:Page in self.pages 
        {
            if case .swift = page.label 
            {
                continue 
            }
            
            page.resolveLinks(at: self)
        }
        for child:Node in self.children.values 
        {
            child.resolveLinks()
        }
    }
    func attachTopics() 
    {
        let nodes:[Node] = self.preorder 
        let global:[String: [Page]] = 
            [String: [(page:Page, membership:(topic:String, rank:Int, order:Int))]]
            .init(grouping: nodes.flatMap 
        {
            $0.pages.flatMap 
            {
                (page:Page) in 
                page.memberships.map 
                {
                    (page: page, membership: $0)
                }
            }
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
        
        for node:Node in nodes 
        {
            // builtin topics 
            var topics: 
            (
                associatedtypes     :[Page],
                cases               :[Page],
                classes             :[Page],
                dependencies        :[Page],
                enumerations        :[Page],
                functions           :[Page],
                functors            :[Page],
                initializers        :[Page],
                instanceMethods     :[Page],
                instanceProperties  :[Page],
                operators           :[Page],
                protocols           :[Page],
                structures          :[Page],
                subscripts          :[Page],
                typealiases         :[Page],
                typeMethods         :[Page],
                typeProperties      :[Page]
            )
            topics = ([], [], [], [], [], [], [], [], [], [], [], [], [], [], [], [], [])
            
            for child:Node in node.children.values 
            {
                for page:Page in child.pages
                {
                    switch page.label 
                    {
                    case .enumeration, .genericEnumeration, .importedEnumeration:
                        topics.enumerations.append(page)
                    case .structure, .genericStructure, .importedStructure:
                        topics.structures.append(page)
                    case .class, .genericClass, .importedClass:
                        topics.classes.append(page)
                    case .protocol, .importedProtocol:
                        topics.protocols.append(page)
                    case .typealias, .genericTypealias, .importedTypealias:
                        topics.typealiases.append(page)
                    case .extension:
                        // extensions go in root node 
                        break 
                    
                    case .enumerationCase:
                        topics.cases.append(page)
                    case .initializer, .genericInitializer:
                        topics.initializers.append(page)
                    case .staticMethod, .genericStaticMethod:
                        topics.typeMethods.append(page)
                    case .instanceMethod, .genericInstanceMethod:
                        topics.instanceMethods.append(page)
                    case .function, .genericFunction:
                        topics.functions.append(page)
                    case .functor, .genericFunctor:
                        topics.functors.append(page)
                    case .operator, .genericOperator:
                        topics.operators.append(page)
                    case .subscript, .genericSubscript:
                        topics.subscripts.append(page)
                    case .staticProperty:
                        topics.typeProperties.append(page)
                    case .instanceProperty:
                        topics.instanceProperties.append(page)
                    case .associatedtype:
                        topics.associatedtypes.append(page)
                    case .module, .plugin, .swift:
                        break
                    
                    case .dependency:
                        topics.dependencies.append(page)
                    }
                }
            }
            
            for page:Page in node.pages
            {
                var seen:Set<ObjectIdentifier> = []
                for i:Int in page.topics.indices 
                {
                    let elements:[Page] = page.topics[i].keys 
                    .flatMap
                    { 
                        global[$0, default: []] 
                    }
                    
                    for element:Page in elements 
                    {
                        page.topics[i].elements.append(.init(target: element))
                        seen.insert(.init(element))
                    }
                }
                // recursively gather extensions 
                let extensions:[Page]
                switch page.label 
                {
                case .module, .plugin: 
                    extensions = nodes.flatMap 
                    {
                        $0.pages.compactMap 
                        {
                            guard case .extension = $0.label
                            else 
                            {
                                return nil
                            }
                            return $0
                        }
                    }
                default:
                    extensions = []
                }
                
                for (builtin, unsorted):(String, [Page]) in 
                [
                    ("Dependencies",        topics.dependencies), 
                    ("Enumeration cases",   topics.cases), 
                    ("Associated types",    topics.associatedtypes), 
                    ("Initializers",        topics.initializers), 
                    ("Functors",            topics.functors), 
                    ("Subscripts",          topics.subscripts), 
                    ("Type properties",     topics.typeProperties), 
                    ("Instance properties", topics.instanceProperties), 
                    ("Type methods",        topics.typeMethods), 
                    ("Instance methods",    topics.instanceMethods), 
                    ("Functions",           topics.functions), 
                    ("Operators",           topics.operators), 
                    ("Enumerations",        topics.enumerations), 
                    ("Structures",          topics.structures), 
                    ("Classes",             topics.classes), 
                    ("Protocols",           topics.protocols), 
                    ("Typealiases",         topics.typealiases), 
                    ("Extensions",          extensions), 
                ]
                {
                    let sorted:[Page] = unsorted
                    .filter 
                    {
                        !seen.contains(.init($0))
                    }
                    .sorted
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
                    
                    page.topics.append(
                        .init(name: builtin, elements: sorted.map(Unowned<Page>.init(target:))))
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
