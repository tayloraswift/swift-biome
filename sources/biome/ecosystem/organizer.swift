extension Ecosystem 
{
    func organizeTopics(forHost host:Symbol.Index, pins:[Package.Index: Version]) 
        -> Topics 
    {
        var topics:Topics = .init()
        if let facts:Symbol.Predicates = self.facts(host, 
            at: pins[host.module.package] ?? self[host.module.package].latest)
        {
            self.organize(topics: &topics, 
                forHost: host, traits: facts.primary, culture: .primary)
            
            for (culture, traits):(Module.Index, Symbol.Traits) in facts.accepted
            {
                self.organize(topics: &topics, 
                    forHost: host, traits: traits, culture: .accepted(culture))
            }
        }
        for source:Module.Pin in self[host].pollen 
        {
            if let traits:Symbol.Traits = self.opinions(of: host, from: source)
            {
                self.organize(topics: &topics, 
                    forHost: host, traits: traits, culture: .international(source)) 
            }
        }
        return topics
    }
    private 
    func organize(topics:inout Topics, 
        forHost host:Symbol.Index, 
        traits:Symbol.Traits, 
        culture:Module.Culture)
    {
        let diacritic:Symbol.Diacritic 
        switch culture 
        {
        case .primary:
            diacritic = .init(host: host, culture: host.module)
        case .accepted(let culture):
            diacritic = .init(host: host, culture: culture)
        case .international(let pin):
            diacritic = .init(host: host, culture: pin.culture)
        }
        
        let host:Symbol = self[host]
        switch (host.color, host.shape) 
        {
        case (.concretetype(_), _): 
            for (index, constraints):(Symbol.Index, Set<Generic.Constraint<Symbol.Index>>) in 
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
                let sublist:Topics.Sublist = .color(self[index].color)
                topics.members[sublist, default: [:]][culture, default: []]
                    .append(.init(natural: index))
            }
            for index:Symbol.Index in traits.features
            {
                let sublist:Topics.Sublist = .color(self[index].color)
                topics.members[sublist, default: [:]][culture, default: []]
                    .append(.init(index, diacritic))
            }
        default: 
            break 
        }
    }
}
