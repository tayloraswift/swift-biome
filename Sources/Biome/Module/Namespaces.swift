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
    let position:PluralPosition<Module>

    var culture:Atom<Module>
    {
        self.position.contemporary
    }

    init(id:Module.ID, position:PluralPosition<Module>)
    {
        self.id = id 
        self.position = position
    }
}
//  the endpoints of a graph edge can reference symbols in either this 
//  package or one of its dependencies. since imports are module-wise, and 
//  not package-wise, it’s possible for multiple index dictionaries to 
//  return matches, as long as only one of them belongs to an depended-upon module.
//  
//  it’s also possible to prefer a dictionary result in a foreign package over 
//  a dictionary result in the local package, if the foreign package contains 
//  a module that shadows one of the modules in the local package (as long 
//  as the target itself does not also depend upon the shadowed local module.)
struct Namespaces
{
    private(set)
    var pins:[Package.Index: Version]
    let module:Namespace
    private(set)
    var linked:[Module.ID: PluralPosition<Module>]

    init(_ module:Namespace)
    {
        self.pins = [:]
        self.module = module 
        self.linked = [module.id: module.position]
    }
    init(id:Module.ID, position:PluralPosition<Module>)
    {
        self.init(.init(id: id, position: position))
    }

    @available(*, deprecated, renamed: "module")
    var current:Namespace 
    {
        self.module
    }

    @available(*, deprecated, renamed: "nationality")
    var package:Package.Index
    {
        self.culture.package
    }
    var nationality:Package.Index
    {
        self.culture.nationality
    }
    var culture:Atom<Module> 
    {
        self.module.culture
    }

    /// Returns a set containing all modules the current module depends on. 
    /// 
    /// This is similar to ``import``, except it excludes the current module.
    func dependencies() -> Set<Atom<Module>>
    {
        .init(self.linked.values.lazy.compactMap 
        { 
            $0.contemporary == self.culture ? nil : $0.contemporary 
        })
    }

    /// Returns a set containing all modules that can be imported, including the 
    /// current module.
    func `import`() -> Set<Atom<Module>>
    {
        .init(self.linked.values.lazy.map(\.contemporary))
    }
    
    /// Returns a set containing all modules that can be imported, among the requested 
    /// list of module names. The current module is always included in the set, 
    /// even if not explicitly requested.
    func `import`(_ modules:some Sequence<Module.ID>) -> Set<Atom<Module>>
    {
        var imported:Set<Atom<Module>> = []
            imported.reserveCapacity(modules.underestimatedCount + 1)
        for module:Module.ID in modules 
        {
            if let position:Atom<Module> = self.linked[module]?.contemporary
            {
                imported.insert(position)
            }
        }
        imported.insert(self.culture)
        return imported
    }

    // the `branch` parameter may be *different* from `module.position.branch`, 
    // which refers to the branch in which the module itself was founded.
    mutating 
    func link(dependencies:[SymbolGraph.Dependency], 
        linkable:[Package.Index: _Dependency], 
        branch:Version.Branch, 
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
            guard self.nationality != package.nationality 
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
        if self.nationality != .swift 
        {
            pinned.update(with: try self.link(upstream: .swift, 
                linkable: linkable, 
                context: context))
            
            if self.nationality != .core 
            {
                pinned.update(with: try self.link(upstream: .core, 
                    linkable: linkable, 
                    context: context))
            }
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
        switch linkable[package.nationality] 
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
                    if let module:PluralPosition<Module> = pinned.modules.find(module)
                    {
                        // use the stored id, not the requested id
                        self.linked[pinned.package.tree[local: module].id] = module
                    }
                    else 
                    {
                        let branch:Branch = pinned.package.tree[version.branch]
                        throw _DependencyError.module(unavailable: module, 
                            (branch.id, branch.revisions[version.revision].hash), 
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
                        self.linked[module.id] = module.index.pluralized(epoch.branch)
                    }
                }
            }
            self.pins[pinned.nationality] = version
            return pinned
        }
    }
    private mutating 
    func link(local package:Package, dependencies:[Module.ID], 
        branch:Version.Branch, 
        fasces:Fasces) 
        throws 
    {
        let contemporary:Branch.Buffer<Module>.SubSequence = 
            package.tree[branch].modules[...]
        for module:Module.ID in dependencies
        {
            if  let module:PluralPosition<Module> = 
                    contemporary.positions[module].map({ $0.pluralized(branch) }) ?? 
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
