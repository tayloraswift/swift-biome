struct Topics 
{
    enum Key:Hashable, Sendable 
    {
        case excerpt(Symbol.Composite)
        case uri(Ecosystem.Index)
    }
    
    enum Sublist:Hashable, CaseIterable, Sendable
    {
        case color(Symbol.Color)
        
        var heading:String 
        {
            switch self 
            {
            case .color(let color): return color.plural
            }
        }
        
        static 
        let allCases:[Self] = Symbol.Color.allCases.map(Self.color(_:))
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
    
    var requirements:[Sublist: [Symbol.Card]]
    var members:[Sublist: [Module.Culture: [Symbol.Card]]]
    var removed:[Sublist: [Module.Culture: [Symbol.Card]]]
    var lists:[List: [Module.Culture: [Generic.Conditional<Symbol.Index>]]]
    
    var isEmpty:Bool 
    {
        self.requirements.isEmpty && 
        self.members.isEmpty && 
        self.removed.isEmpty && 
        self.lists.isEmpty 
    }
    
    init() 
    {
        self.requirements = [:]
        self.members = [:]
        self.removed = [:]
        self.lists = [:]
    }
}

extension Ecosystem.Pinned 
{
    func organize(toplevel:Set<Symbol.Index>) -> Topics 
    {
        var topics:Topics = .init()
        for index:Symbol.Index in toplevel
        {
            // all toplevel symbols are natural and of the module’s primary culture
            self.add(member: .init(natural: index), culture: .primary, to: &topics)
        }
        return topics
    }
    func organize(facts:Symbol.Predicates, host:Symbol.Index) -> Topics 
    {
        var topics:Topics = .init()
        
        if case .protocol = self.ecosystem[host].color
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
        return topics
    }
    private 
    func organize(topics:inout Topics, 
        culture:Module.Culture, 
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
        switch (host.color, host.shape) 
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
    func add(member composite:Symbol.Composite, culture:Module.Culture, to topics:inout Topics)
    {
        let sublist:Topics.Sublist = .color(self.ecosystem[composite.base].color)
        let declaration:Symbol.Declaration = 
            self.pin(composite.base.module.package).declaration(composite.base)
        // every sublist has a sub-sublist for the primary culture, even if it 
        // is empty. this is more css-grid friendly.
        var empty:[Module.Culture: [Symbol.Card]] { [.primary: []] }
        if  declaration.availability.isUsable 
        {
            topics.members[sublist, default: empty][culture, default: []]
                .append((composite, declaration))
        }
        else 
        {
            topics.removed[sublist, default: empty][culture, default: []]
                .append((composite, declaration))
        }
    }
    private 
    func add(role:Symbol.Index, pinned:Package.Pinned, to topics:inout Topics)
    {
        // protocol roles may originate from a different package
        switch self.ecosystem[role].color 
        {
        case .protocol:
            topics.lists[.implications, default: [:]][.primary, default: []]
                .append(.init(role))
        case let color:
            let sublist:Topics.Sublist = .color(color)
            // this is always valid, because non-protocol roles are always 
            // requirements, and requirements always live in the same package as 
            // the protocol they are part of.
            let declaration:Symbol.Declaration = pinned.declaration(role)
            topics.requirements[sublist, default: []]
                .append((.init(natural: role), declaration))
        }
    }
}
