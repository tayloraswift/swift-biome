extension SurfaceBuilder 
{
    struct NaturalRoutes:ExpressibleByArrayLiteral, RandomAccessCollection
    {
        private 
        var elements:[(Route.Key, Position<Symbol>)]

        var startIndex:Int 
        {
            self.elements.startIndex
        }
        var endIndex:Int 
        {
            self.elements.endIndex
        }
        subscript(index:Int) -> (Route.Key, Composite)
        {
            let (key, natural):(Route.Key, Position<Symbol>) = self.elements[index]
            return (key, .init(natural: natural))
        }

        init(arrayLiteral:(Route.Key, Position<Symbol>)...)
        {
            self.elements = arrayLiteral
        }

        mutating 
        func append(_ route:Route.Key, position:Position<Symbol>)
        {
            self.elements.append((route, position))
        }
    }
    struct SyntheticRoutes:RandomAccessCollection 
    {
        private 
        let diacritic:Diacritic, 
            matrix:[(base:Position<Symbol>, leaf:Route.Leaf)]
        private 
        let namespace:Position<Module>, 
            prefix:Route.Stem 

        init?(host:__shared Symbol, 
            diacritic:Diacritic, 
            features:__shared [Position<Symbol>: Version.Branch], 
            context:__shared Context)
        {
            guard let stem:Route.Stem = host.kind.path 
            else 
            {
                return nil
            }
            self.init(host.namespace, stem,
                diacritic: diacritic, 
                features: features, 
                context: context)
        }
        init?(_ namespace:Position<Module>, _ prefix:Route.Stem,
            diacritic:Diacritic, 
            features:__shared [Position<Symbol>: Version.Branch], 
            context:__shared Context)
        {
            if features.isEmpty 
            {
                return nil
            }
            self.matrix = features.map 
            { 
                ($0.key, context[global: .init($0.key, branch: $0.value)].route.leaf) 
            }
            self.diacritic = diacritic
            self.namespace = namespace 
            self.prefix = prefix 
        }

        var startIndex:Int 
        {
            self.matrix.startIndex
        }
        var endIndex:Int 
        {
            self.matrix.endIndex
        }
        subscript(index:Int) -> (Route.Key, Composite)
        {
            let (base, leaf):(Position<Symbol>, Route.Leaf) = self.matrix[index]
            let composite:Composite = .init(base, self.diacritic)
            let key:Route.Key = .init(self.namespace, self.prefix, leaf) 
            return (key, composite)
        }
    }

    struct Routes 
    {
        var natural:NaturalRoutes
        var synthetic:[SyntheticRoutes]

        init() 
        {
            self.natural = []
            self.synthetic = []
        }
    }
}