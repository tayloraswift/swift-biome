extension Package 
{    
    func dependencies<Modules>(_ modules:Modules, given ecosystem:Ecosystem) 
        throws -> [Module.Dependencies]
        where Modules:Sequence, Modules.Element == (Module.Index, Module.Graph)
    {
        try modules.map
        {
            var dependencies:Module.Dependencies = 
                try self.dependencies($0.1.dependencies, given: ecosystem)
            // remove self-import, if present
            dependencies.modules.remove($0.0)
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
        for (id, namespaces):(ID, [Module.ID]) in dependencies 
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
            
            for id:Module.ID in namespaces
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
