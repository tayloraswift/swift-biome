extension SurfaceBuilder 
{
    struct NaturalRoutes:ExpressibleByArrayLiteral, RandomAccessCollection
    {
        private 
        var elements:[(Route.Key, Branch.Position<Symbol>)]

        var startIndex:Int 
        {
            self.elements.startIndex
        }
        var endIndex:Int 
        {
            self.elements.endIndex
        }
        subscript(index:Int) -> (Route.Key, Branch.Composite)
        {
            let (key, natural):(Route.Key, Branch.Position<Symbol>) = self.elements[index]
            return (key, .init(natural: natural))
        }

        init(arrayLiteral:(Route.Key, Branch.Position<Symbol>)...)
        {
            self.elements = arrayLiteral
        }

        mutating 
        func append(_ route:Route.Key, position:Branch.Position<Symbol>)
        {
            self.elements.append((route, position))
        }
    }
    struct SyntheticRoutes:RandomAccessCollection 
    {
        private 
        let diacritic:Branch.Diacritic, 
            matrix:[(base:Branch.Position<Symbol>, leaf:Route.Leaf)]
        private 
        let namespace:Branch.Position<Module>, 
            prefix:Route.Stem 

        init?(host:__shared Symbol, 
            diacritic:Branch.Diacritic, 
            features:__shared [Branch.Position<Symbol>: Version.Branch], 
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
        init?(_ namespace:Branch.Position<Module>, _ prefix:Route.Stem,
            diacritic:Branch.Diacritic, 
            features:__shared [Branch.Position<Symbol>: Version.Branch], 
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
        subscript(index:Int) -> (Route.Key, Branch.Composite)
        {
            let (base, leaf):(Branch.Position<Symbol>, Route.Leaf) = self.matrix[index]
            let composite:Branch.Composite = .init(base, self.diacritic)
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