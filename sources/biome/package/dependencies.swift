extension Package 
{
    func scope(_ dependencies:Module.Dependencies, given ecosystem:Ecosystem) -> Scope
    {
        var scope:Scope = .init()
        for module:Module.Index in dependencies.modules 
        {
            scope.import(self[module] ?? ecosystem[module])
        }
        for package:Index in dependencies.packages
        {
            assert(package != self.index)
            scope.append(lens: ecosystem[package].symbols.indices)
        }
        return scope
    }
    
    func dependencies<Modules>(_ modules:Modules, given ecosystem:Ecosystem) 
        throws -> [Module.Dependencies]
        where Modules:Sequence, Modules.Element == (Module.Index, Module.Graph)
    {
        try modules.map
        {
            var dependencies:Module.Dependencies = 
                try self.dependencies($0.1.dependencies, given: ecosystem)
            // add self-import, if not already present 
            dependencies.modules.insert($0.0)
            return dependencies
        }
    }
    private 
    func dependencies(_ dependencies:[Module.Graph.Dependency], given ecosystem:Ecosystem) 
        throws -> Module.Dependencies
    {
        var dependencies:[ID: [Module.ID]] = [ID: [Module.Graph.Dependency]]
            .init(grouping: dependencies, by: \.package)
            .mapValues 
        {
            $0.flatMap(\.modules)
        }
        // add implicit dependencies 
            dependencies[.swift, default: []].append(contentsOf: ecosystem.standardModules)
        if self.id != .swift 
        {
            dependencies[.core,  default: []].append(contentsOf: ecosystem.coreModules)
        }
        
        var modules:Set<Module.Index> = []
        var packages:Set<Package.Index> = []
        for (id, imports):(ID, [Module.ID]) in dependencies 
        {
            let package:Self 
            if self.id == id
            {
                package = self 
            }
            else if let upstream:Package = ecosystem[id]
            {
                package = upstream
                packages.insert(upstream.index)
            }
            else 
            {
                throw Package.ResolutionError.dependency(id, of: self.id)
            }
            
            for id:Module.ID in imports
            {
                guard let index:Module.Index = package.modules.indices[id]
                else 
                {
                    throw Module.ResolutionError.target(id, in: package.id)
                }
                modules.insert(index)
            }
        }
        return .init(packages: packages, modules: modules)
    }
}
