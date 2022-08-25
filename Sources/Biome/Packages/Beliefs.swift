import SymbolGraphs

extension Sequence<SymbolGraph> 
{
    func generateBeliefs(abstractors:[Abstractor], context:Packages) -> Beliefs 
    {
        var beliefs:Beliefs = .init() 
        for (graph, abstractor):(SymbolGraph, Abstractor) in zip(self, abstractors)
        {
            beliefs.insert(
                statements: graph.statements(abstractor: abstractor, context: context), 
                symbols: abstractor.updates, 
                context: context)
        }
        beliefs.integrate()
        return beliefs 
    }
}
struct Beliefs 
{
    var facts:[Symbol.Index: Symbol.Facts] 
    var opinions:[Symbol.Diacritic: Symbol.Traits] 

    init()
    {
        self.facts = [:]
        self.opinions = [:]
    }

    fileprivate mutating 
    func insert(statements:[Symbol.Statement], 
        symbols:Abstractor.Updates, 
        context:Packages) 
    {
        var traits:[Symbol.Index: [Symbol.Trait<Symbol.Index>]] = [:]
        var roles:[Symbol.Index: [Symbol.Role<Symbol.Index>]] = [:]
        for (subject, predicate):Symbol.Statement in statements 
        {
            switch (symbols.culture == subject.module, predicate)
            {
            case (false,  .is(_)):
                fatalError("unimplemented")
            case (false, .has(let trait)):
                traits  [subject, default: []].append(trait)
            case (true,  .has(let trait)):
                traits  [subject, default: []].append(trait)
            case (true,   .is(let role)):
                roles   [subject, default: []].append(role)
            }
        }
        for symbol:Symbol.Index? in symbols 
        {
            guard let symbol:Symbol.Index 
            else 
            {
                continue 
            }
            self.facts[symbol] = .init(
                traits: traits.removeValue(forKey: symbol) ?? [],
                roles: roles.removeValue(forKey: symbol) ?? [], 
                as: context[symbol].community)
        }
        for (symbol, traits):(Symbol.Index, [Symbol.Trait<Symbol.Index>]) in traits 
        {
            let diacritic:Symbol.Diacritic = .init(host: symbol, culture: symbols.culture)
            self.opinions[diacritic] = .init(traits, as: context[symbol].community)
        }
    }
    fileprivate mutating 
    func integrate() 
    {
        self.opinions = self.opinions.filter 
        {
            guard $0.key.host.module.package == $0.key.culture.package, 
                    let index:Dictionary<Symbol.Index, Symbol.Facts>.Index = 
                        self.facts.index(forKey: $0.key.host)
            else 
            {
                return true 
            }
            self.facts.values[index].predicates.updateAcceptedTraits($0.value, 
                culture: $0.key.culture)
            return false 
        }
    }
}
extension Beliefs 
{
    func generateTrees(context:Packages) -> Route.Trees
    {
        var natural:[Route.NaturalTree] = []
        var synthetic:[Route.SyntheticTree] = []
        for (symbol, facts):(Symbol.Index, Symbol.Facts) in self.facts
        {
            let host:Symbol = context[symbol]
            
            natural.append(.init(key: host.route, target: symbol))
            
            if let stem:Route.Stem = host.kind.path
            {
                for (culture, features):(Module.Index?, Set<Symbol.Index>) in 
                    facts.predicates.featuresAssumingConcreteType()
                {
                    synthetic.append(.init(namespace: host.namespace, stem: stem,
                        diacritic: .init(host: symbol, culture: culture ?? symbol.module), 
                        features: features.map { ($0, context[$0].route.leaf) }))
                } 
            }
        }
        for (diacritic, traits):(Symbol.Diacritic, Symbol.Traits) in self.opinions
        {
            // can have external traits that do not have to do with features
            if !traits.features.isEmpty 
            {
                let host:Symbol = context[diacritic.host]
                if let stem:Route.Stem = host.kind.path
                {
                    synthetic.append(.init(namespace: host.namespace, stem: stem, 
                        diacritic: diacritic, 
                        features: traits.features.map { ($0, context[$0].route.leaf) }))
                }
            }
        }
        return (natural, synthetic)
    }
}
