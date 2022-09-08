struct Lens 
{
    let namespaces:Namespaces
    let upstream:Fasces
    let local:Fasces
    let routes:[Route.Key: Branch.Stack]
    let linked:Set<Branch.Position<Module>>

    var culture:Branch.Position<Module> 
    {
        self.namespaces.culture
    }
    var package:Package.Index
    {
        self.culture.package
    }

    func select(_local route:Route.Key) -> _Selection<Tree.Position<Symbol>>?
    {
        fatalError("unimplemented")
    }
    func select(local route:Route.Key) -> _Selection<Branch.Composite>?
    {
        self.select(route: route, fasces: self.local)
    }
    func select(global route:Route.Key) -> _Selection<Branch.Composite>?
    {
        // upstream dependencies cannot possibly contain a route 
        // with a namespace whose culture is one of its consumers, 
        // so we can skip searching them entirely.
        self.package != route.namespace.package ?
            self.select(route: route, fasces: [self.local, self.upstream].joined()) :
            self.select(local: route)
    }
    private 
    func select(route:Route.Key, fasces:some Sequence<Fascis>) 
        -> _Selection<Branch.Composite>
    {
        var selection:_Selection<Branch.Composite> = .none
        self.routes.select(route)
        {
            if self.linked.contains($0.culture) 
            {
                selection.append($0)
            }
        }
        for fascis:Fascis in fasces 
        {
            fascis.routes.select(route)
            {
                if self.linked.contains($0.culture) 
                {
                    selection.append($0)
                }
            }
        }
        return selection
    }
}
struct Lenses:RandomAccessCollection 
{
    struct Target 
    {
        let namespaces:Namespaces
        let upstream:Fasces
        let routes:[Route.Key: Branch.Stack]
        let linked:Set<Branch.Position<Module>>
    }

    let local:Fasces
    private 
    let targets:[Target]

    var startIndex:Int 
    {
        self.targets.startIndex
    }
    var endIndex:Int 
    {
        self.targets.endIndex
    }
    subscript(index:Int) -> Lens 
    {
        let target:Target = self.targets[index]
        return .init(namespaces: target.namespaces, 
            upstream: target.upstream, 
            local: self.local, 
            routes: target.routes, 
            linked: target.linked)
    }

    init(_ namespaces:__owned [Namespaces], local:__owned Fasces, context:__shared Packages)
    {
        self.local = local
        self.targets = namespaces.map 
        { 
            var upstream:Fasces = []
            for (dependency, version):(Package.Index, _Version) in $0.pins 
            {
                upstream.append(contentsOf: context[dependency].tree.fasces(through: version))
            }
            return .init(namespaces: $0, upstream: upstream, 
                routes: context[$0.package].tree[$0._branch].routes, 
                linked: .init($0.linked.values.lazy.map(\.contemporary)))
        }
    }
}