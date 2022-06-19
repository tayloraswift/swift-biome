extension Ecosystem 
{
    func organize(facts:Symbol.Predicates, 
        pins:[Package.Index: Version],
        host:Symbol.Index) 
        -> Topics 
    {
        var topics:Topics = .init()
        
        if case .protocol = self[host].color,
            let version:Version = pins[host.module.package]
        {
            switch facts.roles 
            {
            case nil: 
                break 
            case .one(let role)?:
                self.add(role: role, at: version, to: &topics)
            case .many(let roles)?:
                for role:Symbol.Index in roles 
                {
                    self.add(role: role, at: version, to: &topics)
                }
            }
        }
        
        self.organize(topics: &topics, 
            culture: .primary, 
            traits: facts.primary,
            pins: pins,
            host: host)
        
        for (culture, traits):(Module.Index, Symbol.Traits) in facts.accepted
        {
            self.organize(topics: &topics, 
                culture: .accepted(culture),
                traits: traits,
                pins: pins,
                host: host)
        }
        for source:Module.Index in 
            Set<Module.Index>.init(self[host].pollen.lazy.map(\.culture))
        {
            if let traits:Symbol.Traits = self.currentOpinions(of: host, from: source)
            {
                self.organize(topics: &topics, 
                    culture: .international(source),
                    traits: traits,
                    pins: pins,
                    host: host)  
            }
        }
        return topics
    }
    private 
    func organize(topics:inout Topics, 
        culture:Module.Culture, 
        traits:Symbol.Traits, 
        pins:[Package.Index: Version],
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
        
        let host:Symbol = self[host]
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
                self.add(member: .init(natural: index), to: &topics, 
                    culture: culture, 
                    pins: pins)
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
                self.add(member: .init(natural: index), to: &topics, 
                    culture: culture, 
                    pins: pins)
            }
            for index:Symbol.Index in traits.features
            {
                self.add(member: .init(index, diacritic), to: &topics, 
                    culture: culture, 
                    pins: pins)
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
    func add(member composite:Symbol.Composite, to topics:inout Topics, 
        culture:Module.Culture, 
        pins:[Package.Index: Version])
    {
        let sublist:Topics.Sublist = .color(self[composite.base].color)
        let declaration:Symbol.Declaration = self.baseDeclaration(composite, 
            pins: pins) 
        if  declaration.availability.isUsable 
        {
            topics.members[sublist, default: [:]][culture, default: []]
                .append((composite, declaration))
        }
        else 
        {
            topics.removed[sublist, default: [:]][culture, default: []]
                .append((composite, declaration))
        }
    }
    private 
    func add(role:Symbol.Index, at version:Version, to topics:inout Topics)
    {
        switch self[role].color 
        {
        case .protocol:
            topics.lists[.implications, default: [:]][.primary, default: []]
                .append(.init(role))
        case let color:
            let sublist:Topics.Sublist = .color(color)
            let declaration:Symbol.Declaration = self.declaration(role, at: version)
            topics.requirements[sublist, default: []]
                .append((.init(natural: role), declaration))
        }
    }
}
