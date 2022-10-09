import SymbolSource 

extension Collection<RawCulturalGraph> 
{
    func topologicallySorted(for package:PackageIdentifier) throws -> [RawCulturalGraph]
    {
        // collect intra-package dependencies
        var dependencies:[ModuleIdentifier: Set<ModuleIdentifier>] = [:]
        for module:RawCulturalGraph in self
        {
            for dependency:PackageDependency in module.dependencies
                where package == dependency.package && !dependency.modules.isEmpty
            {
                dependencies[module.id, default: []].formUnion(dependency.modules)
            }
        }

        var consumers:[ModuleIdentifier: [RawCulturalGraph]] = [:]
        for module:RawCulturalGraph in self
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

        var graphs:[RawCulturalGraph] = []
            graphs.reserveCapacity(self.underestimatedCount)
        // perform topological sort
        var sources:[RawCulturalGraph] = self.compactMap 
        {
            dependencies[$0.id, default: []].isEmpty ? $0 : nil
        }
        while let source:RawCulturalGraph = sources.popLast()
        {
            graphs.append(source)

            guard let next:[RawCulturalGraph] = consumers.removeValue(forKey: source.id)
            else 
            {
                continue 
            }
            for next:RawCulturalGraph in next
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
            throw SymbolGraphValidationError.cyclicModuleDependency
        }
    }
}
