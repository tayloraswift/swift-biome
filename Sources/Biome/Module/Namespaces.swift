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
    let module:Namespace
    private(set)
    var linked:[Module.ID: Tree.Position<Module>]

    init(_ module:Namespace)
    {
        self.pins = [:]
        self.module = module 
        self.linked = [module.id: module.position]
    }
    init(id:Module.ID, position:Tree.Position<Module>)
    {
        self.init(.init(id: id, position: position))
    }

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

    /// Returns a set containing all modules that can be imported.
    func `import`() -> Set<Branch.Position<Module>>
    {
        .init(self.linked.values.lazy.map(\.contemporary))
    }
    
    /// Returns a set containing all modules that can be imported, among the requested 
    /// list of module names.
    func `import`(_ modules:some Sequence<Module.ID>) -> Set<Branch.Position<Module>>
    {
        var imported:Set<Branch.Position<Module>> = []
            imported.reserveCapacity(modules.underestimatedCount)
        for module:Module.ID in modules 
        {
            if let position:Branch.Position<Module> = self.linked[module]?.contemporary
            {
                imported.insert(position)
            }
        }
        return imported
    }

    // the `branch` parameter may be *different* from `module.position.branch`, 
    // which refers to the branch in which the module itself was founded.
    mutating 
    func link(dependencies:[SymbolGraph.Dependency], 
        linkable:[Package.Index: _Dependency], 
        branch:_Version.Branch, 
        fasces:Fasces, 
        context:Packages)
        throws -> [Package.Index: Package._Pinned]
    {
        var pinned:[Package.Index: Package._Pinned] = [:]
            pinned.reserveCapacity(dependencies.count + 2)
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
                    branch: branch, 
                    fasces: fasces)
                continue 
            }

            pinned.update(with: try self.link(upstream: package, 
                dependencies: dependency.modules, 
                linkable: linkable))
        }
        // add implicit dependencies
        switch context[self.package].kind
        {
        case .community(_): 
            pinned.update(with: try self.link(upstream: .core, 
                linkable: linkable, 
                context: context))
            fallthrough 
        case .core: 
            pinned.update(with: try self.link(upstream: .swift, 
                linkable: linkable, 
                context: context))
        case .swift: 
            break 
        }
        return pinned
    }
    private mutating 
    func link(upstream package:Package.ID, 
        linkable:[Package.Index: _Dependency], 
        context:Packages) 
        throws -> Package._Pinned
    {
        if let package:Package = context[package]
        {
            return try self.link(upstream: _move package, linkable: linkable)
        }
        else 
        {
            throw _DependencyError.package(unavailable: package)
        }
    }
    private mutating 
    func link(upstream package:__owned Package, dependencies:[Module.ID]? = nil, 
        linkable:[Package.Index: _Dependency]) 
        throws -> Package._Pinned
    {
        switch linkable[package.index] 
        {
        case nil:
            throw _DependencyError.pin(unavailable: package.id)
        case .unavailable(let requirement, let revision):
            throw _DependencyError.version(unavailable: (requirement, revision), package.id)
        case .available(let version):
            // upstream dependency 
            let pinned:Package._Pinned = .init(_move package, version: version)
            if let dependencies:[Module.ID] 
            {
                for module:Module.ID in dependencies
                {
                    if let module:Tree.Position<Module> = pinned.modules.find(module)
                    {
                        // use the stored id, not the requested id
                        self.linked[pinned.package.tree[local: module].id] = module
                    }
                    else 
                    {
                        let branch:Branch = pinned.package.tree[version.branch]
                        throw _DependencyError.module(unavailable: module, 
                            (branch.id, branch[version.revision].hash), 
                            pinned.package.id)
                    }
                }
            }
            else 
            {
                for epoch:Epoch<Module> in pinned.modules 
                {
                    for module:Module in epoch 
                    {
                        self.linked[module.id] = epoch.branch.pluralize(module.index)
                    }
                }
            }
            self.pins[pinned.package.index] = version
            return pinned
        }
    }
    private mutating 
    func link(local package:Package, dependencies:[Module.ID], 
        branch:_Version.Branch, 
        fasces:Fasces) 
        throws 
    {
        let contemporary:Branch.Buffer<Module>.SubSequence = 
            package.tree[branch].modules[...]
        for module:Module.ID in dependencies
        {
            if  let module:Tree.Position<Module> = 
                    contemporary.positions[module].map(branch.pluralize(_:)) ?? 
                    fasces.modules.find(module) 
            {
                // use the stored id, not the requested id
                self.linked[package.tree[local: module].id] = module
            }
            else 
            {
                throw _DependencyError.target(unavailable: module, 
                    package.tree[branch].id)
            }
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