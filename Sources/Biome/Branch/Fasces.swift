struct Fasces
{
    struct ForeignView:RandomAccessCollection
    {
        private 
        let segments:[Fascis]

        init(_ segments:__owned [Fascis])
        {
            self.segments = segments
        }

        var startIndex:Int 
        {
            self.segments.startIndex
        }
        var endIndex:Int 
        {
            self.segments.endIndex
        }
        subscript(index:Int) -> Divergences<Diacritic, Symbol.ForeignDivergence>
        {
            self.segments[index].foreign
        }
    }
    struct ArticleView:RandomAccessCollection
    {
        private 
        let segments:[Fascis]

        init(_ segments:__owned [Fascis])
        {
            self.segments = segments
        }

        var startIndex:Int 
        {
            self.segments.startIndex
        }
        var endIndex:Int 
        {
            self.segments.endIndex
        }
        subscript(index:Int) -> Epoch<Article> 
        {
            self.segments[index].articles
        }
    }
    struct SymbolView:RandomAccessCollection
    {
        private 
        let segments:[Fascis]

        init(_ segments:__owned [Fascis])
        {
            self.segments = segments
        }

        var startIndex:Int 
        {
            self.segments.startIndex
        }
        var endIndex:Int 
        {
            self.segments.endIndex
        }
        subscript(index:Int) -> Epoch<Symbol>
        {
            self.segments[index].symbols
        }
    }
    struct ModuleView:RandomAccessCollection
    {
        private 
        let segments:[Fascis]

        init(_ segments:__owned [Fascis])
        {
            self.segments = segments
        }

        var startIndex:Int 
        {
            self.segments.startIndex
        }
        var endIndex:Int 
        {
            self.segments.endIndex
        }
        subscript(index:Int) -> Epoch<Module> 
        {
            self.segments[index].modules
        }
    }
    struct RoutingView:RandomAccessCollection
    {
        private 
        let segments:[Fascis]

        init(_ segments:__owned [Fascis])
        {
            self.segments = segments
        }

        var startIndex:Int 
        {
            self.segments.startIndex
        }
        var endIndex:Int 
        {
            self.segments.endIndex
        }
        subscript(index:Int) -> Divergences<Route, Branch.Stack> 
        {
            self.segments[index].routes
        }
    }
    struct AugmentedRoutingView
    {
        private 
        let trunk:[Fascis], 
            routes:[Route: Branch.Stack], 
            branch:Version.Branch

        init(_ trunk:[Fascis], 
            routes:[Route: Branch.Stack], 
            branch:Version.Branch)
        {
            self.trunk = trunk 
            self.routes = routes
            self.branch = branch
        }

        func select<T>(_ key:Route, 
            where filter:(Version.Branch, Composite) throws -> T?) rethrows -> Selection<T>?
        {
            var selection:Selection<T>? = nil
            try self.select(key)
            {
                if let selected:T = try filter($0, $1)
                {
                    selection.append(selected)
                }
            }
            return selection
        }
        private 
        func select(_ key:Route, 
            _ body:(Version.Branch, Composite) throws -> ()) rethrows 
        {
            try self.routes.select(key) 
            { 
                try body(self.branch, $0) 
            }
            for fascis:Fascis in self.trunk 
            {
                try fascis.routes.select(key) 
                { 
                    try body(fascis.branch, $0)
                }
            }
        }
    }

    private
    var segments:[Fascis]

    init() 
    {
        self.segments = []
    }
    init(_ segments:__owned [Fascis])
    {
        self.segments = segments
    }

    var articles:ArticleView 
    {
        .init(self.segments)
    }
    var symbols:SymbolView 
    {
        .init(self.segments)
    }
    var modules:ModuleView 
    {
        .init(self.segments)
    }
    var foreign:ForeignView 
    {
        .init(self.segments)
    }
    var routes:RoutingView 
    {
        .init(self.segments)
    }
    func routes(layering routes:[Route: Branch.Stack], branch:Version.Branch) 
        -> AugmentedRoutingView 
    {
        .init(self.segments, routes: routes, branch: branch)
    }
}
extension Fasces:ExpressibleByArrayLiteral 
{
    init(arrayLiteral:Fascis...)
    {
        self.init(arrayLiteral)
    }
}
extension Fasces:RandomAccessCollection, RangeReplaceableCollection 
{
    var startIndex:Int 
    {
        self.segments.startIndex
    }
    var endIndex:Int 
    {
        self.segments.endIndex
    }
    subscript(index:Int) -> Fascis
    {
        _read 
        {
            yield self.segments[index]
        }
    }
    mutating 
    func replaceSubrange(_ subrange:Range<Int>, with elements:some Collection<Fascis>) 
    {
        self.segments.replaceSubrange(subrange, with: elements)
    }
}

extension Sequence 
{
    func find<Axis>(_ id:Axis.ID) -> Atom<Axis>.Position? where Element == Epoch<Axis>
    {
        for segment:Epoch<Axis> in self 
        {
            if let atom:Atom<Axis> = segment.atom(of: id)
            {
                return atom.positioned(segment.branch)
            }
        }
        return nil
    }
}