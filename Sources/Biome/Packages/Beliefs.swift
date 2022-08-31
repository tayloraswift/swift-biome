import SymbolGraphs

extension Sequence<SymbolGraph> 
{
    @available(*, deprecated)
    func generateBeliefs(abstractors:[Abstractor], context:Packages) -> Beliefs 
    {
        fatalError("obsoleted")
    }
}

struct Belief 
{
    enum Predicate 
    {
        case `is`(Symbol.Role<Symbol.Index>)
        case has(Symbol.Trait<Symbol.Index>)
    }

    let subject:Tree.Position<Symbol>
    let predicate:Predicate

    init(_ subject:Tree.Position<Symbol>, _ predicate:Predicate)
    {
        self.subject = subject 
        self.predicate = predicate
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

    private mutating 
    func insert(_ beliefs:[Belief], symbols:_Abstractor.UpdatedSymbols, context:Packages) 
    {
        typealias UncheckedFacts = 
        (
            roles:[Symbol.Role<Symbol.Index>], 
            traits:[Symbol.Trait<Symbol.Index>]
        )
        typealias UncheckedOpinions = 
        (
            branch:_Version.Branch, 
            traits:[Symbol.Trait<Symbol.Index>]
        )

        var facts:[Symbol.Index: UncheckedFacts] = [:]
        var opinions:[Symbol.Index: UncheckedOpinions] = [:]
        for belief:Belief in beliefs 
        {
            let key:Symbol.Index = belief.subject.index
            switch (symbols.culture == key.module, belief.predicate)
            {
            case (false,  .is(_)):
                fatalError("unimplemented")
            case (false, .has(let trait)):
                opinions[key, default: (belief.subject.branch, [])].traits.append(trait)
            case (true,  .has(let trait)):
                facts[key, default: ([], [])].traits.append(trait)
            case (true,   .is(let role)):
                facts[key, default: ([], [])].roles.append(role)
            }
        }
        for symbol:Tree.Position<Symbol>? in symbols 
        {
            if let symbol:Tree.Position<Symbol>
            {
                let (roles, traits):UncheckedFacts = facts.removeValue(forKey: symbol.index) ?? 
                    ([],    [])
                self.facts[symbol.index] = .init(traits: traits, roles: roles, 
                    as: context[global: symbol].community) 
            }
        }
        guard facts.isEmpty 
        else 
        {
            fatalError("unimplemented")
        }
        for (symbol, (branch, traits)):(Symbol.Index, UncheckedOpinions) in opinions 
        {
            let position:Tree.Position<Symbol> = .init(symbol, branch: branch)
            let diacritic:Symbol.Diacritic = .init(host: symbol, culture: symbols.culture)
            self.opinions[diacritic] = .init(traits, as: context[global: position].community)
        }
    }

    mutating 
    func update(with edges:[SymbolGraph.Edge<Int>], abstractor:_Abstractor, context:Packages)
    {
        let (beliefs, errors):([Belief], [_Abstractor.LookupError]) = 
            abstractor.translate(edges: edges, context: context)
        
        if !errors.isEmpty 
        {
            print("warning: dropped \(errors.count) edges")
        }
        
        self.insert(beliefs, symbols: abstractor.updatedSymbols, context: context)
    }

    mutating 
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
