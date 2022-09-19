extension SurfaceBuilder 
{
    struct AtomicRoutes:ExpressibleByArrayLiteral, RandomAccessCollection
    {
        private 
        var elements:[(Route, Atom<Symbol>)]

        var startIndex:Int 
        {
            self.elements.startIndex
        }
        var endIndex:Int 
        {
            self.elements.endIndex
        }
        subscript(index:Int) -> (Route, Composite)
        {
            let (key, natural):(Route, Atom<Symbol>) = self.elements[index]
            return (key, .init(natural: natural))
        }

        init(arrayLiteral:(Route, Atom<Symbol>)...)
        {
            self.elements = arrayLiteral
        }

        mutating 
        func append(_ route:Route, position:Atom<Symbol>)
        {
            self.elements.append((route, position))
        }
    }
    struct CompoundRoutes:RandomAccessCollection 
    {
        private 
        let diacritic:Diacritic, 
            matrix:[(base:Atom<Symbol>, leaf:Route.Leaf)]
        private 
        let namespace:Atom<Module>, 
            prefix:Route.Stem 

        init?(host:__shared Symbol, 
            diacritic:Diacritic, 
            features:__shared [Atom<Symbol>: Version.Branch], 
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
        init?(_ namespace:Atom<Module>, _ prefix:Route.Stem,
            diacritic:Diacritic, 
            features:__shared [Atom<Symbol>: Version.Branch], 
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
        subscript(index:Int) -> (Route, Composite)
        {
            let (base, leaf):(Atom<Symbol>, Route.Leaf) = self.matrix[index]
            let composite:Composite = .init(base, self.diacritic)
            let key:Route = .init(self.namespace, self.prefix, leaf) 
            return (key, composite)
        }
    }

    struct Routes 
    {
        var atomic:AtomicRoutes
        var compound:[CompoundRoutes]

        init() 
        {
            self.atomic = []
            self.compound = []
        }
    }
}