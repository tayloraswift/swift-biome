import SymbolSource 

extension SymbolGraph 
{
    public 
    enum DependencyError:Error 
    {
        case moduleCycle(in:PackageIdentifier)
    }
}

extension Collection<SymbolGraph> 
{
    public 
    func topologicallySorted(for package:PackageIdentifier) throws -> [SymbolGraph]
    {
        // collect intra-package dependencies
        var dependencies:[ModuleIdentifier: Set<ModuleIdentifier>] = [:]
        for module:SymbolGraph in self
        {
            for dependency:SymbolGraph.Dependency in module.dependencies
                where package == dependency.package && !dependency.modules.isEmpty
            {
                dependencies[module.id, default: []].formUnion(dependency.modules)
            }
        }
        var consumers:[ModuleIdentifier: [SymbolGraph]] = [:]
        for module:SymbolGraph in self
        {
            guard let dependencies:Set<ModuleIdentifier> = dependencies[module.id]
            else 
            {
                continue 
            }
            // need to sort dependency set to make topological sort deterministic
            for dependency:ModuleIdentifier in dependencies.sorted()
            {
                consumers[dependency, default: []].append(module)
            }
        }

        var graphs:[SymbolGraph] = []
            graphs.reserveCapacity(self.underestimatedCount)
        // perform topological sort
        var sources:[SymbolGraph] = self.compactMap 
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
                guard let index:Dictionary<ModuleIdentifier, Set<ModuleIdentifier>>.Index = 
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
            throw SymbolGraph.DependencyError.moduleCycle(in: package)
        }
    }
}