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

    var culture:Module.Index 
    {
        self.position.index
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
    let current:Namespace
    private(set)
    var positions:[Module.ID: Tree.Position<Module>]
    
    init(_ current:Namespace)
    {
        self.pins = [:]
        self.current = current 
        self.positions = [current.id: current.position]
    }
    init(id:Module.ID, position:Tree.Position<Module>)
    {
        self.init(.init(id: id, position: position))
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
        throws -> [Trunk]
    {
        guard let package:Package = context[package]
        else 
        {
            throw _DependencyError.package(unavailable: package)
        }
        guard self.current.culture.package != package.index
        else 
        {
            guard let dependencies:[Module.ID] 
            else 
            {
                fatalError("unreachable")
            }
            // local dependency 
            let trunks:[Trunk] = package.tree.prefix(through: self.current.position.branch)
            for module:Module.ID in dependencies
            {
                if let module:Tree.Position<Module> = trunks.find(module: module)
                {
                    // use the stored id, not the requested id
                    self.link(id: package.tree[local: module].id, position: module)
                }
                else 
                {
                    throw _DependencyError.target(unavailable: module, 
                        package.tree[self.current.position.branch].id)
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
            let trunks:[Trunk] = package.tree.prefix(upTo: version)
            if let dependencies:[Module.ID] 
            {
                for module:Module.ID in dependencies
                {
                    if let module:Tree.Position<Module> = trunks.find(module: module)
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
                for trunk:Trunk in trunks 
                {
                    for module:Module in trunk.modules
                    {
                        self.link(id: module.id, position: trunk.position(module.index))
                    }
                }
            }
            self.pins[package.index] = version
            return trunks 
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