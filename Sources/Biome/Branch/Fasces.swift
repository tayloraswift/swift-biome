// protocol TrunkView<Axis>:RandomAccessCollection where Element == Branch.Epoch<Axis>
// {
//     associatedtype Axis:BranchElement where Axis.Divergence:Voidable
// }

// extension Branch 
// {
//     struct AugmentedEpochs<Trunk> where Trunk:TrunkView, Trunk.Element == Epoch<Trunk.Axis>
//     {
//         let trunk:Trunk
//         let layer:Trunk.Layer
//         let branch:_Version.Branch 
//     }

// }
// extension Augmented
// {

// }

struct Fasces
{
    // struct Augmented<Trunk> where Trunk:TrunkView
    // {
    //     let trunk:Trunk
    //     let layer:Branch.Buffer<Trunk.Axis>
    //     let branch:_Version.Branch 
    // }
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
        subscript(index:Int) -> Branch.Epoch<Module> 
        {
            self.segments[index].modules
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
        subscript(index:Int) -> Branch.Epoch<Symbol>
        {
            self.segments[index].symbols
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
        subscript(index:Int) -> Branch.Epoch<Article> 
        {
            self.segments[index].articles
        }
    }
    struct RoutingView
    {
        private 
        let segments:[Fascis]
        private 
        let layered:(routes:[Route.Key: Branch.Stack], branch:_Version.Branch)?

        init(_ segments:__owned [Fascis], 
            layering layered:(routes:[Route.Key: Branch.Stack], branch:_Version.Branch)?)
        {
            self.segments = segments
            self.layered = layered
        }

        func select<T>(_ key:Route.Key, 
            _ filter:(_Version.Branch, Branch.Composite) throws -> T?) rethrows -> _Selection<T>
        {
            var selection:_Selection<T> = .none
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
        func select(_ key:Route.Key, 
            _ body:(_Version.Branch, Branch.Composite) throws -> ()) rethrows 
        {
            if case let (routes, branch)? = self.layered 
            {
                try routes.select(key) 
                { 
                    try body(branch, $0) 
                }
            }
            for fascis:Fascis in self.segments 
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

    var modules:ModuleView 
    {
        .init(self.segments)
    }
    var symbols:SymbolView 
    {
        .init(self.segments)
    }
    var articles:ArticleView 
    {
        .init(self.segments)
    }
    func routes(layering branch:Branch?) -> RoutingView 
    {
        .init(self.segments, layering: branch.map { ($0.routes, $0.index) })
    }
    func routes(layering routes:[Route.Key: Branch.Stack], branch:_Version.Branch) -> RoutingView 
    {
        .init(self.segments, layering: (routes, branch))
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
    func find<Axis>(_ id:Axis.ID) -> Tree.Position<Axis>? 
        where Element == Branch.Epoch<Axis>
    {
        for segment:Branch.Epoch<Axis> in self 
        {
            if let position:Branch.Position<Axis> = segment.position(of: id)
            {
                return segment.branch.pluralize(position)
            }
        }
        return nil
    }
}