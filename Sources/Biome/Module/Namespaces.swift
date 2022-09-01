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
    var positions:[Module.ID: Tree.Position<Module>]

    @available(*, deprecated, renamed: "module")
    var current:Namespace 
    {
        self.module
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
        self.positions = [module.id: module.position]
    }
    init(id:Module.ID, position:Tree.Position<Module>, _branch:_Version.Branch)
    {
        self.init(.init(id: id, position: position), _branch: _branch)
    }

    private mutating 
    func link(id:Module.ID, position:Tree.Position<Module>)
    {
        self.positions[id] = position
    }
    mutating 
    func link(package:Package.ID, dependencies:[Module.ID]? = nil, 
        linkable:[Package.Index: _Dependency], 
        context:Packages) 
        throws -> [Fascis]
    {
        guard let package:Package = context[package]
        else 
        {
            throw _DependencyError.package(unavailable: package)
        }
        guard self.culture.package != package.index
        else 
        {
            guard let dependencies:[Module.ID] 
            else 
            {
                fatalError("unreachable")
            }
            // local dependency 
            let fasces:[Fascis] = package.tree.prefix(through: self._branch)
            for module:Module.ID in dependencies
            {
                if let module:Tree.Position<Module> = fasces.find(module: module)
                {
                    // use the stored id, not the requested id
                    self.link(id: package.tree[local: module].id, position: module)
                }
                else 
                {
                    throw _DependencyError.target(unavailable: module, 
                        package.tree[self._branch].id)
                }
            }
            return []
        }
        switch linkable[package.index] 
        {
        case nil:
            throw _DependencyError.pin(unavailable: package.id)
        case .unavailable(let requirement, let revision):
            throw _DependencyError.version(unavailable: (requirement, revision), package.id)
        case .available(let version):
            // upstream dependency 
            let fasces:[Fascis] = package.tree.prefix(upTo: version)
            if let dependencies:[Module.ID] 
            {
                for module:Module.ID in dependencies
                {
                    if let module:Tree.Position<Module> = fasces.find(module: module)
                    {
                        // use the stored id, not the requested id
                        self.link(id: package.tree[local: module].id, position: module)
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
                for fascis:Fascis in fasces 
                {
                    for module:Module in fascis.modules
                    {
                        self.link(id: module.id, position: fascis.branch.pluralize(module.index))
                    }
                }
            }
            self.pins[package.index] = version
            return fasces 
        }
    }
}
extension Namespaces 
{
    func lens(local fasces:[Fascis], context:Packages) -> Lens 
    {
        var fasces:[Fascis] = fasces 
        for (upstream, version):(Package.Index, _Version) in self.pins 
        {
            fasces.append(contentsOf: context[upstream].tree.prefix(upTo: version))
        }
        return .init(namespaces: self, fasces: fasces, 
            routes: context[self.culture.package].tree[self._branch].routes)
    }
}
struct Lens 
{
    let namespaces:Namespaces
    let fasces:[Fascis]
    let routes:[Route.Key: Route.Stack]

    var culture:Branch.Position<Module> 
    {
        self.namespaces.culture
    }

    func select(_ route:Route.Key) -> Route._Selection<Tree.Composite>?
    {
        fatalError("unimplemented")
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