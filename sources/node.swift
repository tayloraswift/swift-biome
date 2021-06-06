protocol Node:AnyObject, CustomStringConvertible
{
    var parent:InternalNode?
    {
        get 
    }
    var children:[String: Node]
    {
        get 
    }
    var pages:[Page] 
    {
        get 
    }
}
extension Node 
{
    var allPages:[Page] 
    {
        self.pages + self.children.values.flatMap(\.allPages)
    }
    
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


final 
class LeafNode:Node 
{
    private(set) weak
    var parent:InternalNode?
    
    var children:[String: Node] 
    {
        [:]
    }
    
    private(set)
    var pages:[Page]
    
    init(page:Page, parent:InternalNode?) 
    {
        self.parent     = parent 
        self.pages      = [page]
    }
    
    func append(_ page:Page)
    {
        self.pages.append(page)
    }
}
final 
class InternalNode:Node 
{
    private(set) weak
    var parent:InternalNode?
    private(set)
    var children:[String: Node]
    
    var pages:[Page]
    {
        [self.page] + self.extensions
    }
    
    let page:Page 
    private 
    var extensions:[Page]
    
    init(page:Page, parent:InternalNode?) 
    {
        self.parent     = parent 
        self.page       = page
        self.children   = [:]
        self.extensions = []
    }
}

extension InternalNode 
{
    private 
    enum InsertionRule:Hashable, Comparable  
    {
        case leaf  
        case `internal`  
        case `extension`
    }
    
    static 
    func tree<T>(_ symbols:[Symbol], _ body:(InternalNode) throws -> T) rethrows -> T 
    {
        var levels:[Int: [Symbol]] = .init(grouping: symbols, by: \.fields.path.count)
        
        // find root symbol and create root node 
        let root:InternalNode
        if  let toplevel:[Symbol]  = levels.removeValue(forKey: 0),
            let symbol:Symbol      = toplevel.first 
        {
            // sanity check 
            guard case .framework(let header) = symbol.header
            else 
            {
                // framework fields are the only headers that can generate an empty path
                fatalError("unreachable")
            }
            
            for ignored:Symbol in toplevel.dropFirst() 
            {
                guard case .framework(let ignored) = ignored.header
                else 
                {
                    fatalError("unreachable")
                }
                
                print("warning: ignored framework doccomment '\(ignored.identifier)' because there is already a root node (\(header.identifier))")
            }
            do 
            {
                root = .init(page: try .init(header, fields: symbol.fields), parent: nil)
            }
            catch let error 
            {
                fatalError("\(error)")
            }
        }
        else 
        {
            fatalError("missing framework root symbol")
        }
        
        // tree building 
        return try withExtendedLifetime(root)
        {
            // load standard library symbols 
            let swift:[Int: [Symbol.Pseudo]] =
                .init(grouping: StandardLibrary.symbols, by: \.fields.path.count)
            for symbol:Symbol.Pseudo in (swift.sorted{ $0.key < $1.key }.flatMap(\.value))
            {
                do 
                {
                    try root.insert(.internal, at: symbol.fields.path[...])
                    {
                        (parent:InternalNode) in 
                        
                        .init(parent:   parent, 
                            anchor:     symbol.anchor, 
                            kind:       symbol.kind,
                            generics:   symbol.generics,
                            fields:     symbol.fields, 
                            name:       "$builtin", 
                            signature:      .empty, 
                            declaration:    .empty)
                    }
                }
                catch let error 
                {
                    print("ignored symbol '\(symbol.fields.path.joined(separator: "."))' because \(error)")
                    continue 
                }
            }
            
            for level:[Symbol] in (levels.sorted{ $0.key < $1.key }.map(\.value))
            {
                // need to insert extensions *last*, but we cannot use `Array.partition`
                // because that sort is non-stable 
                let partitioned:[InsertionRule: [Symbol]] = .init(grouping: level)
                {
                    switch $0.header 
                    {
                    case    .framework:
                        fatalError("unreachable")
                    case    .dependency, .lexeme,
                            .associatedtype, .typealias:
                        return .internal 
                    case    .type(let header):
                        if case .extension = header.keyword 
                        {
                            return .extension 
                        }
                        else 
                        {
                            return .internal 
                        }
                    case    .subscript, .function, .property:
                        return .leaf 
                    }
                }
                
                for (rule, symbols):(InsertionRule, [Symbol]) in 
                    (partitioned.sorted{ $0.key < $1.key })
                {
                    for symbol:Symbol in symbols 
                    {
                        // check if the first path component matches a standard 
                        // library symbol, to avoid generating extraneous nodes 
                        // (which will mess up link resolution later)
                        var fields:Page.Fields  = symbol.fields 
                        if  let first:String    = fields.path.first, first != "Swift", 
                            let _:Node          = root.find(["Swift", first])
                        {
                            fields.path = ["Swift"] + fields.path 
                        }
                        
                        do 
                        {
                            try root.insert(rule, at: fields.path[...])
                            {
                                (parent:InternalNode) in 
                                
                                switch symbol.header 
                                {
                                case .framework: 
                                    fatalError("unreachable")
                                case .dependency    (let header): 
                                    return try .init(header, fields: fields, parent: parent)
                                case .lexeme        (let header): 
                                    return try .init(header, fields: fields, parent: parent)
                                case .associatedtype(let header): 
                                    return try .init(header, fields: fields, parent: parent)
                                case .typealias     (let header): 
                                    return try .init(header, fields: fields, parent: parent)
                                case .type          (let header): 
                                    return try .init(header, fields: fields, parent: parent)
                                case .subscript     (let header): 
                                    return try .init(header, fields: fields, parent: parent)
                                case .function      (let header): 
                                    return try .init(header, fields: fields, parent: parent)
                                case .property      (let header): 
                                    return try .init(header, fields: fields, parent: parent)
                                }
                            }
                        }
                        catch let error 
                        {
                            print("ignored symbol '\(fields.path.joined(separator: "."))' because \(error)")
                            continue 
                        }
                    }
                }
            }
            
            return try body(root)
        }
    }
    
    private 
    func insert(_ rule:InsertionRule, at path:ArraySlice<String>, page:(InternalNode) throws -> Page) 
        throws 
    {
        guard let key:String = path.first 
        else 
        {
            fatalError("unreachable")
        }
        
        let path:ArraySlice<String> = path.dropFirst()
        if  path.isEmpty 
        {
            let page:Page = try page(self)
            switch rule 
            {
            case .extension: 
                // node must already exist, and must be an internal node  
                switch self.children[key] 
                {
                case .none:
                    throw Entrapta.Error.extensionTargetDoesNotExist
                case .some(let node as LeafNode):
                    throw Entrapta.Error.extensionTargetIsLeafNode(node)
                case .some(let node as InternalNode):
                    node.extensions.append(page)
                default: 
                    fatalError("unreachable")
                }
                
            case .leaf:
                // can be overloaded, cannot have children 
                switch self.children[key] 
                {
                case .none:
                    self.children[key] = LeafNode.init(page: page, parent: self)
                case .some(let node as LeafNode):
                    node.append(page)
                case .some(let node as InternalNode): 
                    throw Entrapta.Error.cannotOverloadInternalNode(node)
                default: 
                    fatalError("unreachable")
                }
            case .internal:
                // cannot be overloaded (except by extensions), can have children 
                switch self.children[key] 
                {
                case .none:
                    self.children[key] = InternalNode.init(page: page, parent: self)
                case .some(let node as LeafNode):
                    throw Entrapta.Error.cannotOverloadLeafNode(node)
                case .some(let node as InternalNode):
                    throw Entrapta.Error.cannotOverloadInternalNode(node)
                default: 
                    fatalError("unreachable")
                }
            }
        }
        else 
        {
            switch self.children[key] 
            {
            case .none: 
                throw Entrapta.Error.ancestorNodeDoesNotExist
            case .some(let node as LeafNode):
                throw Entrapta.Error.ancestorNodeIsLeafNode(node)
            case .some(let node as InternalNode):
                try node.insert(rule, at: path, page: page)
            default: 
                fatalError("unreachable")
            }
        }
    }
}

extension Node 
{
    func preorder(_ body:(Node) throws -> ()) rethrows 
    {
        try body(self)
        
        for child:Node in self.children.values 
        {
            try child.preorder(body)
        }
    }
    
    var ancestors:[InternalNode]
    {
        var ancestors:[InternalNode]    = []
        var current:Node                = self
        while let next:InternalNode     = current.parent
        {
            ancestors.append(next)
            current = next 
        }
        return .init(ancestors.reversed())
    }
    
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
    func find(_ paths:[[String]]) -> [Node]
    {
        paths.compactMap(self.find(_:))
    }
    func find(conformable path:[String]) -> InternalNode? 
    {
        guard let node:Node = self.find(path) 
        else 
        {
            print("warning: could not find upstream node for conformance target '\(path.joined(separator: "."))'")
            return nil 
        }
        guard let target:InternalNode = node as? InternalNode
        else 
        {
            print("warning: could not find upstream node for conformance target '\(path.joined(separator: "."))'")
            print("note: candidates are \(node.pages.map(\.kind)), expected a class or protocol")
            return nil 
        }
        switch target.page.kind 
        {
        case .class, .protocol:
            return target 
        case let kind:
            print("warning: could not find upstream node for conformance target '\(path.joined(separator: "."))'") 
            print("note: candidate is a \(kind), expected a class or protocol")
            return nil
        }
    }
    func find(protocol path:[String]) -> InternalNode? 
    {
        guard let node:InternalNode = self.find(conformable: path) 
        else 
        {
            // warning was already printed 
            return nil 
        }
        guard case .protocol = node.page.kind
        else 
        {
            print("warning: could not find upstream node for conformance target '\(path.joined(separator: "."))'") 
            print("note: candidate is a \(node.page.kind), expected a protocol")
            return nil 
        }
        return node
    }
    func search(space inclusions:[Page.Context.Predicate]) 
        -> [[(node:Node, pages:[Page])]]
    {
        let spaces:[(Page.Context.Predicate) -> [String]?] = 
        [
            \.alias, 
            \.inheritance
        ]
        return spaces.map 
        {
            // recursively gather inclusions. `seen` set guards against graph cycles 
            var seen:Set<ObjectIdentifier>          = []
            var space:[(node:Node, pages:[Page])]  = []
            
            var frontier:[[String]] = inclusions.compactMap($0) 
            while !frontier.isEmpty
            {
                let nodes:[Node]    = self.find(frontier)
                frontier            = []
                for node:Node in nodes 
                    where seen.update(with: .init(node)) == nil
                {
                    frontier.append(contentsOf: node.pages.flatMap(\.inclusions).compactMap($0))
                    space.append((node, node.pages))
                }
            }
            
            return space 
        }
    }
}

extension InternalNode 
{
    func append(downstream page:Page, in node:InternalNode, as kind:Page.Conformer.Kind) 
    {        
        self.page.downstream.append(.init(kind: kind,
            node:   .init(target: node),
            page:   .init(target: page)))
        
        guard case .conformer(where: let conditions) = kind, conditions.isEmpty
        else 
        {
            return 
        }
        
        // if there were no conditions, we should recurse upstream, 
        // so this page appears as conforming to unconditionally-inherited 
        // protocols as well 
        var frontier:[InternalNode]         = [      self ]
        var seen:Set<ObjectIdentifier>      = [.init(self)]
        while let inheriting:InternalNode   = frontier.popLast()
        {
            for inherited:[String] in inheriting.page.upstream.map(\.path)
            {
                guard let inherited:InternalNode = inheriting.find(protocol: inherited)
                else 
                {
                    // warning was already printed
                    continue 
                }
                // no point in registering conformances to builtin protocols/classes
                if case .swift              = inherited.page.kind.module 
                {
                    continue 
                }
                if let _:ObjectIdentifier   = seen.update(with: .init(inherited))
                {
                    continue 
                }
                
                inherited.append(downstream: page, in: node, 
                    as: .inheritedConformer(actualConformance: self.page.path))                
                frontier.append(inherited)
            }
        }
    }
}
extension Node 
{
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
            // only internal nodes can appear in rivers 
            guard let node:InternalNode = node as? InternalNode 
            else 
            {
                return 
            }
            
            // *all* pages, including extensions 
            for page:Page in node.pages 
            {
                for (path, conditions):([String], [Grammar.WhereClause]) in page.upstream
                {
                    var description:String 
                    {
                        "conformance target '\(path.joined(separator: "."))'"
                    }
                    
                    // find the upstream node and page 
                    guard let upstream:InternalNode = node.find(conformable: path) 
                    else 
                    {
                        // warning was already printed
                        continue 
                    }
                    // no point in registering conformances to builtin protocols/classes
                    if case .swift = upstream.page.kind.module
                    {
                        continue 
                    }
                    // make sure the relationship makes sense 
                    switch (page.kind, upstream.page.kind)
                    {
                    case (.class, .class):
                        guard conditions.isEmpty 
                        else 
                        {
                            print("warning: \(description) is a class, which cannot be conditionally conformed-to")
                            continue 
                        }
                        upstream.append(downstream: page, in: node, as: .subclass)
                    case (_     , .class):
                        print("warning: \(description) is a class, which cannot be inherited by a \(page.kind)")
                        continue 
                    case (.protocol, .protocol):
                        upstream.append(downstream: page, in: node, as: .refinement)
                    case (.enum, .protocol), (.struct, .protocol), (.class, .protocol), (.extension, .protocol):
                        upstream.append(downstream: page, in: node, as: .conformer(where: conditions))
                    case (let downstream, let upstream):
                        print("warning: \(description) is a \(upstream), which cannot be inherited by a \(downstream)")
                        continue 
                    }
                }
            }
        }
        
        // resolve remaining links 
        self.preorder 
        {
            (node:Node) in 
            
            for page:Page in node.pages 
            {
                if case .swift = page.kind.module 
                {
                    continue 
                }
                
                page.resolveLinks(at: node)
                
                // consolidate duplicated conformers 
                // (happens if a protocol has more than one refinement, and a 
                // type unconditionally conforms to multiple refinements)
                page.rivers = [ObjectIdentifier: [Page.Conformer]]
                .init(grouping: page.downstream) 
                {
                    .init($0.page.target)
                }
                .values.compactMap 
                {
                    (conformers:[Page.Conformer]) -> 
                    (
                        page    :Unowned<Page>, 
                        river   :Page.River, 
                        display :Signature, 
                        note    :Paragraph
                    )? in 
                    
                    guard let conformer:Page.Conformer = conformers.first
                    else 
                    {
                        fatalError("unreachable")
                    }
                    
                    let node:Node = conformer.node.target, 
                        page:Page = conformer.page.target 
                    
                    @Signature 
                    var signature:Signature 
                    {
                        // print the “short” signature, which includes deep generics, 
                        // and is different from the normal signature. 
                        for (identifier, ancestor):(String, InternalNode) in 
                            // omit `Swift` prefix
                            zip(page.path, node.ancestors.dropFirst()).drop(while: 
                            { 
                                if case .module(.swift) = $0.1.page.kind
                                {
                                    return true 
                                }
                                else 
                                {
                                    return false 
                                }
                            })
                        {
                            Signature.text(highlighting: identifier)
                            Signature.init(generics: ancestor.page.parameters)
                            Signature.punctuation(".")
                        }
                        if let identifier:String = page.path.last 
                        {
                            Signature.text(highlighting: identifier)
                            Signature.init(generics: page.parameters)
                        }
                    }
                     
                    switch (conformer.kind, conformers.count)
                    {
                    case (.subclass,                         1):
                        return (conformer.page, .subclass,   signature, .empty)
                    case (.refinement,                       1): 
                        return (conformer.page, .refinement, signature, .empty)
                    case (.conformer(where: let conditions), 1):
                        if conditions.isEmpty 
                        {
                            return (conformer.page, .conformer, signature, .empty)
                        }
                        // resolve links *now*, since the original scope is different 
                        // from the page it will appear in 
                        let note:Paragraph = page.resolveLinks(
                            in: 
                            (
                                .init(parsing: "When \(Page.prose(conditions: conditions))."), 
                                .init()
                            ),
                            at: node)
                        return (conformer.page, .conformer,  signature, note)
                    case (.inheritedConformer,   _):
                        // all conformers should be of this kind
                        let actualConformances:[[String]] = conformers.compactMap 
                        {
                            if case .inheritedConformer(actualConformance: let actual) = $0.kind
                            {
                                return actual 
                            }
                            else 
                            {
                                return nil 
                            }
                        }
                        guard actualConformances.count == conformers.count 
                        else 
                        {
                            fallthrough
                        }
                        let note:Paragraph = page.resolveLinks(
                            in: 
                            (   .init(parsing: 
                                """
                                Because it conforms to \(Page.prose(separator: ",", listing: actualConformances)
                                {
                                    "[`\($0.joined(separator: "."))`]"
                                }).
                                """), 
                                .init()
                            ),
                            at: node)
                        return (conformer.page, .conformer, signature, note)
                    
                    default: 
                        print("error: conflicting downstream conformers (\(conformers.map(\.kind)))")
                        return nil 
                    }
                }
                .sorted 
                {
                    // sort the downstream conformances 
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
                if case .extension = page.kind 
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
                
                let children:[Page]                 = node.children.values.flatMap(\.pages)
                let filter:Set<ObjectIdentifier>    = .init(children.map(ObjectIdentifier.init(_:)))
                
                let infrequent:[Page]               = global["$infrequently-used", default: []]
                .compactMap
                {
                    filter.contains(.init($0)) ? $0 : nil
                }
                seen.formUnion(infrequent.map(ObjectIdentifier.init(_:)))
                
                for page:Page in children
                    where !seen.contains(.init(page))
                {
                    guard let topic:Page.Topic.Builtin = page.kind.topic 
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
                    
                    page.topics.append(.init(name: topic.rawValue, 
                        elements: sorted.map(Unowned<Page>.init(target:))))
                }
                // infrequently-used builtin. do not sort, because `globals` was 
                // already sorted, by explicit page rank
                page.topics.append(.init(name: "Infrequently-used functionality", 
                    elements: infrequent.map(Unowned<Page>.init(target:))))
                
                // move 'see also' to the end 
                if let i:Int = (page.topics.firstIndex
                { 
                    $0.name.lowercased() == "see also" 
                })
                {
                    let moved:Page.Topic = page.topics.remove(at: i)
                    page.topics.append(moved)
                }
                // remove empty topics 
                page.topics.removeAll(where: \.elements.isEmpty)
            }
        }
    }
}
