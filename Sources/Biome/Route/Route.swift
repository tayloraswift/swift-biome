struct Route 
{
}
extension Route
{
    struct Cohort 
    {
        struct Naturals:ExpressibleByArrayLiteral, RandomAccessCollection
        {
            var elements:[(Key, Branch.Position<Symbol>)]

            var startIndex:Int 
            {
                self.elements.startIndex
            }
            var endIndex:Int 
            {
                self.elements.endIndex
            }
            subscript(index:Int) -> (Key, Branch.Composite)
            {
                let (key, natural):(Key, Branch.Position<Symbol>) = self.elements[index]
                return (key, .init(natural: natural))
            }

            init(arrayLiteral:(Key, Branch.Position<Symbol>)...)
            {
                self.elements = arrayLiteral
            }
        }
        struct Synthetics:RandomAccessCollection 
        {
            let namespace:Module.Index 
            let stem:Route.Stem 
            let diacritic:Branch.Diacritic 
            let matrix:[(base:Symbol.Index, leaf:Leaf)]

            var startIndex:Int 
            {
                self.matrix.startIndex
            }
            var endIndex:Int 
            {
                self.matrix.endIndex
            }
            subscript(index:Int) -> (Key, Branch.Composite)
            {
                let (base, leaf):(Symbol.Index, Leaf) = self.matrix[index]
                let composite:Branch.Composite = .init(base, self.diacritic)
                let key:Key = .init(self.namespace, self.stem, leaf) 
                return (key, composite)
            }
        }

        var naturals:Naturals
        var synthetics:[Synthetics]

        init(beliefs:__shared Beliefs, context:__shared Packages)
        {
            self.naturals = []
            self.synthetics = []
            self.update(with: beliefs.facts, context: context)
            self.update(with: beliefs.opinions, context: context)
        }
        private mutating 
        func update(with facts:[Tree.Position<Symbol>: Symbol.Facts<Tree.Position<Symbol>>], 
            context:Packages)
        {
            for (symbol, facts):(Tree.Position<Symbol>, Symbol.Facts<Tree.Position<Symbol>>) in 
                facts
            {
                let host:Symbol = context[global: symbol]
                
                self.naturals.elements.append((host.route, symbol.contemporary))
                
                if let stem:Route.Stem = host.kind.path
                {
                    for (culture, features):(Branch.Position<Module>?, Set<Tree.Position<Symbol>>) in 
                        facts.predicates.featuresAssumingConcreteType()
                    {
                        let diacritic:Branch.Diacritic = .init(host: symbol.contemporary, 
                            culture: culture ?? symbol.contemporary.culture)
                        self.synthetics.append(diacritic.inflect(features, 
                            namespace: host.namespace, stem: stem,
                            context: context))
                    } 
                }
            }
        }
        private mutating 
        func update(with opinions:[Tree.Diacritic: Symbol.Traits<Tree.Position<Symbol>>], 
            context:Packages)
        {
            for (diacritic, traits):(Tree.Diacritic, Symbol.Traits<Tree.Position<Symbol>>) in 
                opinions
            {
                // can have external traits that do not have to do with features
                if !traits.features.isEmpty 
                {
                    let host:Symbol = context[global: diacritic.host]
                    if let stem:Route.Stem = host.kind.path
                    {
                        self.synthetics.append(diacritic.contemporary.inflect(traits.features, 
                            namespace: host.namespace, stem: stem, 
                            context: context))
                    }
                }
            }
        }
    }
}