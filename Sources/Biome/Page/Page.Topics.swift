import SymbolGraphs

extension Page 
{
    enum Card 
    {
        case composite(Symbol.Composite, Declaration<Symbol.Index>)
        case article(Article.Index, Article.Excerpt)
    }
    
    enum Sublist:Hashable, CaseIterable, Sendable
    {
        case community(Community)
        
        var heading:String 
        {
            switch self 
            {
            case .community(let community): return community.plural
            }
        }
        
        static 
        let allCases:[Self] = Community.allCases.map(Self.community(_:))
    }
    enum List:String, Hashable, Sendable 
    {
        case conformers         = "Conforming Types"
        case conformances       = "Conforms To"
        case subclasses         = "Subclasses"
        case implications       = "Implies"
        case refinements        = "Refinements"
        case implementations    = "Implemented By"
        case restatements       = "Restated By"
        case overrides          = "Overridden By"
    }
    struct Topics 
    {
        enum Key:Hashable, Sendable 
        {
            case composite(Symbol.Composite)
            case article(Article.Index)
            case href(Ecosystem.Index)
        }
        
        var feed:[Card]
        var requirements:[Sublist: [Card]]
        var members:[Sublist: [Module._Culture: [Card]]]
        var removed:[Sublist: [Module._Culture: [Card]]]
        var lists:[List: [Module._Culture: [Generic.Conditional<Symbol.Index>]]]
        
        var isEmpty:Bool 
        {
            self.feed.isEmpty &&
            self.requirements.isEmpty && 
            self.members.isEmpty && 
            self.removed.isEmpty && 
            self.lists.isEmpty 
        }
        
        init() 
        {
            self.feed = []
            self.requirements = [:]
            self.members = [:]
            self.removed = [:]
            self.lists = [:]
        }
        
        mutating 
        func sort(by ecosystem:Ecosystem)
        {
            self.feed.sort(by: ecosystem)
            self.requirements.sortValues(by: ecosystem)
            for index:Dictionary<Sublist, [Module._Culture: [Card]]>.Index in self.members.indices 
            {
                self.members.values[index].sortValues(by: ecosystem)
            }
            for index:Dictionary<Sublist, [Module._Culture: [Card]]>.Index in self.removed.indices 
            {
                self.removed.values[index].sortValues(by: ecosystem)
            }
            for index:Dictionary<List, [Module._Culture: [Generic.Conditional<Symbol.Index>]]>.Index in 
                self.lists.indices 
            {
                self.lists.values[index].sortValues(by: ecosystem)
            }
        }
    }
}

extension Page
{
    func organize(toplevel:Set<Symbol.Index>, guides:Set<Article.Index>) -> Topics 
    {
        var topics:Topics = .init()
        for article:Article.Index in guides
        {
            let excerpt:Article.Excerpt = 
                self.pin(article.module.package).excerpt(article)
            topics.feed.append(.article(article, excerpt))
        }
        for symbol:Symbol.Index in toplevel
        {
            // all toplevel symbols are natural and of the module’s primary culture
            self.add(member: .init(natural: symbol), culture: .primary, to: &topics)
        }
        
        topics.sort(by: self.ecosystem)
        return topics
    }
    func organize(facts:Symbol.Predicates, host:Symbol.Index) -> Topics 
    {
        var topics:Topics = .init()
        
        if case .protocol = self.ecosystem[host].community
        {
            let pinned:Package.Pinned = self.pin(host.module.package)
            switch facts.roles 
            {
            case nil: 
                break 
            case .one(let role)?:
                self.add(role: role, pinned: pinned, to: &topics)
            case .many(let roles)?:
                for role:Symbol.Index in roles 
                {
                    self.add(role: role, pinned: pinned, to: &topics)
                }
            }
        }
        
        self.organize(topics: &topics, 
            culture: .primary, 
            traits: facts.primary,
            host: host)
        
        for (culture, traits):(Module.Index, Symbol.Traits) in facts.accepted
        {
            self.organize(topics: &topics, 
                culture: .accepted(culture),
                traits: traits,
                host: host)
        }
        for source:Module.Index in 
            Set<Module.Index>.init(self.ecosystem[host].pollen.lazy.map(\.culture))
        {
            let diacritic:Symbol.Diacritic = .init(host: host, culture: source)
            if  let traits:Symbol.Traits = 
                self.ecosystem[source.package].currentOpinion(diacritic)
            {
                self.organize(topics: &topics, 
                    culture: .international(source),
                    traits: traits,
                    host: host)  
            }
        }
        
        topics.sort(by: self.ecosystem)
        return topics
    }
    private 
    func organize(topics:inout Topics, 
        culture:Module._Culture, 
        traits:Symbol.Traits, 
        host:Symbol.Index)
    {
        let diacritic:Symbol.Diacritic 
        switch culture 
        {
        case .primary:
            diacritic = .init(host: host, culture: host.module)
        case .accepted(let culture):
            diacritic = .init(host: host, culture: culture)
        case .international(let culture):
            diacritic = .init(host: host, culture: culture)
        }
        
        let host:Symbol = self.ecosystem[host]
        switch (host.community, host.shape) 
        {
        case (_, .requirement(of: _)?):
            for index:Symbol.Index in traits.downstream
            {
                topics.lists[.restatements, default: [:]][culture, default: []]
                    .append(.init(index))
            }
            for index:Symbol.Index in traits.implementations
            {
                topics.lists[.implementations, default: [:]][culture, default: []]
                    .append(.init(index))
            }
        
        case (.protocol, _): 
            for (index, constraints):(Symbol.Index, [Generic.Constraint<Symbol.Index>]) in 
                traits.conformers
            {
                topics.lists[.conformers, default: [:]][culture, default: []]
                    .append(.init(index, where: constraints))
            }
            for index:Symbol.Index in traits.downstream
            {
                topics.lists[.refinements, default: [:]][culture, default: []]
                    .append(.init(index))
            }
            for index:Symbol.Index in traits.members
            {
                self.add(member: .init(natural: index), culture: culture, to: &topics)
            }
        
        case (.concretetype(_), _): 
            for (index, constraints):(Symbol.Index, [Generic.Constraint<Symbol.Index>]) in 
                traits.conformances
            {
                topics.lists[.conformances, default: [:]][culture, default: []]
                    .append(.init(index, where: constraints))
            }
            for index:Symbol.Index in traits.downstream
            {
                topics.lists[.subclasses, default: [:]][culture, default: []]
                    .append(.init(index))
            }
            for index:Symbol.Index in traits.members
            {
                self.add(member: .init(natural: index), culture: culture, to: &topics)
            }
            for index:Symbol.Index in traits.features
            {
                self.add(member: .init(index, diacritic), culture: culture, to: &topics)
            }
        
        case (.callable(_), _):
            for index:Symbol.Index in traits.downstream
            {
                topics.lists[.overrides, default: [:]][culture, default: []]
                    .append(.init(index))
            }
        
        default: 
            break 
        }
    }
    private 
    func add(member composite:Symbol.Composite, culture:Module._Culture, to topics:inout Topics)
    {
        let sublist:Sublist = .community(self.ecosystem[composite.base].community)
        let declaration:Declaration<Symbol.Index> = 
            self.pin(composite.base.module.package).declaration(composite.base)
        // every sublist has a sub-sublist for the primary culture, even if it 
        // is empty. this is more css-grid friendly.
        var empty:[Module._Culture: [Card]] { [.primary: []] }
        if  declaration.availability.isUsable 
        {
            topics.members[sublist, default: empty][culture, default: []]
                .append(.composite(composite, declaration))
        }
        else 
        {
            topics.removed[sublist, default: empty][culture, default: []]
                .append(.composite(composite, declaration))
        }
    }
    private 
    func add(role:Symbol.Index, pinned:Package.Pinned, to topics:inout Topics)
    {
        // protocol roles may originate from a different package
        switch self.ecosystem[role].community 
        {
        case .protocol:
            topics.lists[.implications, default: [:]][.primary, default: []]
                .append(.init(role))
        case let community:
            let sublist:Sublist = .community(community)
            // this is always valid, because non-protocol roles are always 
            // requirements, and requirements always live in the same package as 
            // the protocol they are part of.
            let declaration:Declaration<Symbol.Index> = pinned.declaration(role)
            topics.requirements[sublist, default: []]
                .append(.composite(.init(natural: role), declaration))
        }
    }
}

extension MutableCollection 
    where Self:RandomAccessCollection, Element == Generic.Conditional<Symbol.Index>
{
    fileprivate mutating 
    func sort(by ecosystem:Ecosystem) 
    {
        self.sort
        {
            ecosystem[$0.target].path.lexicographicallyPrecedes(ecosystem[$1.target].path)
        }
    }
}
extension MutableCollection 
    where Self:RandomAccessCollection, Element == Page.Card
{
    fileprivate mutating 
    func sort(by ecosystem:Ecosystem) 
    {
        self.sort 
        {
            // this lexicographic ordering sorts by last path component first, 
            // and *then* by vending protocol (if applicable)
            let path:(Path, Path) 
            switch ($0, $1)
            {
            case (.article(_, _), .composite(_, _)):
                return true 
            case (.article(let first, _), .article(let second, _)):
                path = (ecosystem[first].path, ecosystem[second].path)
            case (.composite(let first, _), .composite(let second, _)):
                path = (ecosystem[first.base].path, ecosystem[second.base].path)
            case (.composite(_, _), .article(_, _)):
                return false
            }
            if  path.0.last < path.1.last 
            {
                return true 
            }
            else if path.0.last == path.1.last 
            {
                return path.0.prefix.lexicographicallyPrecedes(path.1.prefix)
            }
            else 
            {
                return false 
            }
        }
    }
}
extension Dictionary 
    where   Value:MutableCollection & RandomAccessCollection, 
            Value.Element == Generic.Conditional<Symbol.Index>
{
    fileprivate mutating 
    func sortValues(by ecosystem:Ecosystem)
    {
        for index:Index in self.indices 
        {
            self.values[index].sort(by: ecosystem)
        }
    }
}
extension Dictionary 
    where   Value:MutableCollection & RandomAccessCollection, 
            Value.Element == Page.Card 
{
    fileprivate mutating 
    func sortValues(by ecosystem:Ecosystem)
    {
        for index:Index in self.indices 
        {
            self.values[index].sort(by: ecosystem)
        }
    }
}
