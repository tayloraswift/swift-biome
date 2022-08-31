import SymbolGraphs 

extension Packages 
{
    static 
    func sort(_ package:Package.ID, graphs modules:[SymbolGraph]) throws -> [SymbolGraph]
    {
        // collect intra-package dependencies
        var dependencies:[Module.ID: Set<Module.ID>] = [:]
        for module:SymbolGraph in modules 
        {
            for dependency:SymbolGraph.Dependency in module.dependencies
                where package == dependency.package && !dependency.modules.isEmpty
            {
                dependencies[module.id, default: []].formUnion(dependency.modules)
            }
        }
        var consumers:[Module.ID: [SymbolGraph]] = [:]
        for module:SymbolGraph in modules 
        {
            guard let dependencies:Set<Module.ID> = dependencies[module.id]
            else 
            {
                continue 
            }
            // need to sort dependency set to make topological sort deterministic
            for dependency:Module.ID in dependencies.sorted()
            {
                consumers[dependency, default: []].append(module)
            }
        }

        var graphs:[SymbolGraph] = []
            graphs.reserveCapacity(modules.count)
        // perform topological sort
        var sources:[SymbolGraph] = modules.compactMap 
        {
            dependencies[$0.id, default: []].isEmpty ? $0 : nil
        }
        while let source:SymbolGraph = sources.popLast()
        {
            graphs.append(source)

            guard let next:[SymbolGraph] = consumers.removeValue(forKey: source.id)
            else 
            {
                continue 
            }
            for next:SymbolGraph in next
            {
                guard let index:Dictionary<Module.ID, Set<Module.ID>>.Index = 
                    dependencies.index(forKey: next.id)
                else 
                {
                    // already added module to sorted output
                    continue 
                }
                    dependencies.values[index].remove(source.id)
                if  dependencies.values[index].isEmpty 
                {
                    dependencies.remove(at: index)
                    sources.append(next)
                }
            }
        }
        if dependencies.isEmpty, consumers.isEmpty 
        {
            return graphs 
        }
        else 
        {
            throw DependencyError.moduleCycle(in: package)
        }
    }
}