import SymbolGraphs
//  the endpoints of a graph edge can reference symbols in either this 
//  package or one of its dependencies. since imports are module-wise, and 
//  not package-wise, it’s possible for multiple index dictionaries to 
//  return matches, as long as only one of them belongs to an depended-upon module.
//  
//  it’s also possible to prefer a dictionary result in a foreign package over 
//  a dictionary result in the local package, if the foreign package contains 
//  a module that shadows one of the modules in the local package (as long 
//  as the target itself does not also depend upon the shadowed local module.)
struct Namespace 
{
    let id:Module.ID 
    let position:Tree.Position<Module>

    var culture:Branch.Position<Module>
    {
        self.position.contemporary
    }

    init(id:Module.ID, position:Tree.Position<Module>)
    {
        self.id = id 
        self.position = position
    }
}
struct Namespaces
{
    private(set)
    var pins:[Package.Index: _Version]
    // this branch may be *different* from `current.position.branch`, 
    // which refers to the branch in which the module itself was founded.
    let _branch:_Version.Branch
    let module:Namespace
    private(set)
    var linked:[Module.ID: Tree.Position<Module>]

    @available(*, deprecated, renamed: "module")
    var current:Namespace 
    {
        self.module
    }

    var package:Package.Index
    {
        self.culture.package
    }
    var culture:Branch.Position<Module> 
    {
        self.module.culture
    }
    
    init(_ module:Namespace, _branch:_Version.Branch)
    {
        self.pins = [:]
        self._branch = _branch
        self.module = module 
        self.linked = [module.id: module.position]
    }
    init(id:Module.ID, position:Tree.Position<Module>, _branch:_Version.Branch)
    {
        self.init(.init(id: id, position: position), _branch: _branch)
    }

    mutating 
    func link(dependencies:[SymbolGraph.Dependency], 
        linkable:[Package.Index: _Dependency], 
        fasces:Fasces, 
        context:Packages)
        throws -> Fasces
    {
        var global:Fasces = fasces
        // add explicit dependencies 
        for dependency:SymbolGraph.Dependency in dependencies
        {
            guard let package:Package = context[dependency.package]
            else 
            {
                throw _DependencyError.package(unavailable: dependency.package)
            }
            guard self.package != package.index 
            else 
            {
                try self.link(local: package, dependencies: dependency.modules, 
                    fasces: fasces)
                continue 
            }

            global.append(contentsOf: try self.link(upstream: package, 
                dependencies: dependency.modules, 
                linkable: linkable))
        }
        // add implicit dependencies
        switch context[self.package].kind
        {
        case .community(_): 
            global.append(contentsOf: try self.link(upstream: .core, 
                linkable: linkable, 
                context: context))
            fallthrough 
        case .core: 
            global.append(contentsOf: try self.link(upstream: .swift, 
                linkable: linkable, 
                context: context))
        case .swift: 
            break 
        }
        return global
    }
    private mutating 
    func link(upstream package:Package.ID, 
        linkable:[Package.Index: _Dependency], 
        context:Packages) 
        throws -> Fasces
    {
        if let package:Package = context[package]
        {
            return try self.link(upstream: package, linkable: linkable)
        }
        else 
        {
            throw _DependencyError.package(unavailable: package)
        }
    }
    private mutating 
    func link(upstream package:Package, dependencies:[Module.ID]? = nil, 
        linkable:[Package.Index: _Dependency]) 
        throws -> Fasces
    {
        switch linkable[package.index] 
        {
        case nil:
            throw _DependencyError.pin(unavailable: package.id)
        case .unavailable(let requirement, let revision):
            throw _DependencyError.version(unavailable: (requirement, revision), package.id)
        case .available(let version):
            // upstream dependency 
            let fasces:Fasces = package.tree.fasces(through: version)
            if let dependencies:[Module.ID] 
            {
                for module:Module.ID in dependencies
                {
                    if let module:Tree.Position<Module> = fasces.modules.find(module)
                    {
                        // use the stored id, not the requested id
                        self.linked[package.tree[local: module].id] = module
                    }
                    else 
                    {
                        let branch:Branch = package.tree[version.branch]
                        throw _DependencyError.module(unavailable: module, 
                            (branch.id, branch[version.revision].hash), 
                            package.id)
                    }
                }
            }
            else 
            {
                for epoch:Branch.Epoch<Module> in fasces.modules 
                {
                    for module:Module in epoch 
                    {
                        self.linked[module.id] = epoch.branch.pluralize(module.index)
                    }
                }
            }
            self.pins[package.index] = version
            return fasces
        }
    }
    private mutating 
    func link(local package:Package, dependencies:[Module.ID], fasces:Fasces) throws 
    {
        let contemporary:Branch.Buffer<Module>.SubSequence = 
            package.tree[self._branch].modules[...]
        for module:Module.ID in dependencies
        {
            if  let module:Tree.Position<Module> = 
                    contemporary.positions[module].map(self._branch.pluralize(_:)) ?? 
                    fasces.modules.find(module) 
            {
                // use the stored id, not the requested id
                self.linked[package.tree[local: module].id] = module
            }
            else 
            {
                throw _DependencyError.target(unavailable: module, 
                    package.tree[self._branch].id)
            }
        }
    }
}

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

extension Module 
{
    //  the endpoints of a graph edge can reference symbols in either this 
    //  package or one of its dependencies. since imports are module-wise, and 
    //  not package-wise, it’s possible for multiple index dictionaries to 
    //  return matches, as long as only one of them belongs to an depended-upon module.
    //  
    //  it’s also possible to prefer a dictionary result in a foreign package over 
    //  a dictionary result in the local package, if the foreign package contains 
    //  a module that shadows one of the modules in the local package (as long 
    //  as the target itself does not also depend upon the shadowed local module.)
    struct Scope
    {
        private 
        var namespaces:[ID: Index]
        private(set)
        var filter:Set<Index>
        let culture:Index
        
        subscript(namespace:ID) -> Index?
        {
            _read 
            {
                yield self.namespaces[namespace]
            }
        }
        
        private 
        init(culture:Index, namespaces:[ID: Index])
        {
            self.culture = culture 
            self.namespaces = namespaces 
            self.filter = .init(namespaces.values)
        }
        init(culture:Index, id:ID)
        {
            self.init(culture: culture, namespaces: [id: culture])
        }
        
        mutating 
        func insert(_ namespace:Index, id:ID)
        {
            self.namespaces[id] = namespace
            self.filter.insert(namespace)
        }
        
        func contains(_ namespace:ID) -> Bool
        {
            self.namespaces.keys.contains(namespace)
        }
        func contains(_ namespace:Index) -> Bool
        {
            self.filter.contains(namespace)
        }
        
        func dependencies() -> Set<Module.Index>
        {
            var dependencies:Set<Module.Index> = self.filter 
                dependencies.remove(self.culture)
            return dependencies
        }
        
        func `import`(_ modules:Set<ID>, swift:Package.Index?) -> Self 
        {
            .init(culture: self.culture, namespaces: self.namespaces.filter 
            {
                if case $0.value.package? = swift
                {
                    return true 
                }
                else if $0.value == self.culture
                {
                    return true 
                }
                else 
                {
                    return modules.contains($0.key)
                }
            })
        }
    }
}