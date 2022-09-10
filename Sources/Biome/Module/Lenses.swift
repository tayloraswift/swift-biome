struct Lens 
{
    struct UpstreamDependency 
    {
        let metadata:Package.Metadata
        let fasces:Fasces 
    }
    struct LocalDependency 
    {
        let metadata:Package.Metadata
        let routes:[Route.Key: Branch.Stack]
        let branch:_Version.Branch
        let fasces:Fasces

        init(_ package:__shared Package, branch:_Version.Branch, fasces:__owned Fasces)
        {
            self.metadata = package.metadata 
            self.routes = package.tree[branch].routes 
            self.branch = branch 
            self.fasces = fasces
        }

        // func select<T>(_ route:Route.Key, 
        //     _ filter:(_Version.Branch, Branch.Composite) throws -> T?) rethrows -> _Selection<T>
        // {
        //     self.fasces.routes(layering: self.routes, branch: self.branch)
        //         .select(route)
        //     {
        //         if self.linked.contains($1.culture) 
        //         {
        //             selection.append($1)
        //         }
        //     }
        // }
    }

    let namespaces:Namespaces
    let linked:Set<Branch.Position<Module>>
    let upstream:[UpstreamDependency]
    let local:LocalDependency
    
    var culture:Branch.Position<Module> 
    {
        self.namespaces.culture
    }
    var package:Package.Index
    {
        self.culture.package
    }

    // func select(local route:Route.Key) -> _Selection<Branch.Composite>?
    // {
    //     self.select(route: route, fasces: self.local)
    // }
    // func select(global route:Route.Key) -> _Selection<Branch.Composite>?
    // {
    //     // upstream dependencies cannot possibly contain a route 
    //     // with a namespace whose culture is one of its consumers, 
    //     // so we can skip searching them entirely.
    //     self.package != route.namespace.package ?
    //         self.select(route: route, fasces: [self.local, self.upstream].joined()) :
    //         self.select(local: route)
    // }
    // private 
    // func select(route:Route.Key, fasces:some Sequence<Fascis>) 
    //     -> _Selection<Branch.Composite>
    // {
    //     var selection:_Selection<Branch.Composite> = 
    //         self.local.fasces.routes(layering: self.local.routes, branch: self.local.branch)
    //             .select(route)
    //     {
    //         if self.linked.contains($1.culture) 
    //         {
    //             selection.append($1)
    //         }
    //     }
    //     for fascis:Fascis in fasces 
    //     {
    //         fascis.routes.select(route)
    //         {
    //             if self.linked.contains($0.culture) 
    //             {
    //                 selection.append($0)
    //             }
    //         }
    //     }
    //     return selection
    // }
}
struct Lenses:RandomAccessCollection 
{
    private 
    struct Target 
    {
        let namespaces:Namespaces
        let upstream:[Lens.UpstreamDependency]
        let linked:Set<Branch.Position<Module>>
    }

    private 
    let targets:[Target]
    private 
    let local:Lens.LocalDependency

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
        return .init(namespaces: target.namespaces, linked: target.linked,
            upstream: target.upstream,
            local: self.local)
    }

    init(_   local:__owned Lens.LocalDependency, 
        namespaces:__owned [Namespaces], 
        context:__shared Packages)
    {
        self.local = local
        self.targets = namespaces.map 
        { 
            var upstream:[Lens.UpstreamDependency] = []
            for (dependency, version):(Package.Index, _Version) in $0.pins 
            {
                let dependency:Package = context[dependency]
                upstream.append(.init(metadata: dependency.metadata, 
                    fasces: dependency.tree.fasces(through: version)))
            }
            return .init(namespaces: $0, upstream: upstream, 
                linked: .init($0.linked.values.lazy.map(\.contemporary)))
        }
    }
}