extension Ecosystem 
{
    func computeDependencies(of cultures:[Module.Index], graphs:[Module.Graph]) 
        throws -> [Set<Module.Index>]
    {
        var dependencies:[Set<Module.Index>] = []
            dependencies.reserveCapacity(cultures.count)
        for (graph, culture):(Module.Graph, Module.Index) in zip(graphs, cultures)
        {
            // remove self-dependencies 
            var set:Set<Module.Index> = try self.identify(graph.dependencies)
                set.remove(culture)
            dependencies.append(set)
        }
        return dependencies
    }
    
    private 
    func identify(_ dependencies:[Module.Graph.Dependency]) throws -> Set<Module.Index>
    {
        let packages:[Package.ID: [Module.ID]] = [Package.ID: [Module.Graph.Dependency]]
            .init(grouping: dependencies, by: \.package)
            .mapValues 
        {
            $0.flatMap(\.modules)
        }
        // add implicit dependencies 
        var namespaces:Set<Module.Index> = self.standardLibrary
        if let core:Package = self[.core]
        {
            namespaces.formUnion(core.modules.indices.values)
        }
        for (dependency, targets):(Package.ID, [Module.ID]) in packages
        {
            guard let package:Package = self[dependency]
            else 
            {
                throw DependencyError.packageNotFound(dependency)
            }
            for target:Module.ID in targets
            {
                guard let index:Module.Index = package.modules.indices[target]
                else 
                {
                    throw DependencyError.targetNotFound(target, in: dependency)
                }
                namespaces.insert(index)
            }
        }
        return namespaces
    }
}
