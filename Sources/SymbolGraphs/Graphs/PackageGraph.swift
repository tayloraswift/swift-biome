public
struct PackageGraph:Identifiable, Sendable
{
    public 
    let id:PackageIdentifier 
    public 
    var brand:String?
    public 
    var modules:[SymbolGraph]
    
    public 
    init(id:ID, brand:String? = nil, modules:[SymbolGraph])
    {
        self.id = id 
        self.brand = brand
        // collect intra-package dependencies
        var dependencies:[ModuleIdentifier: Set<ModuleIdentifier>] = [:]
        for module:SymbolGraph in modules 
        {
            for dependency:SymbolGraph.Dependency in module.dependencies
                where self.id == dependency.package
            {
                for dependency:ModuleIdentifier in dependency.modules 
                {
                    dependencies[module.id, default: []].insert(dependency)
                }
            }
        }
        var consumers:[ModuleIdentifier: [SymbolGraph]] = [:]
        for module:SymbolGraph in modules 
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

        self.modules = []
        self.modules.reserveCapacity(modules.count)
        // perform topological sort
        var sources:[SymbolGraph] = modules.compactMap 
        {
            dependencies[$0.id, default: []].isEmpty ? $0 : nil
        }
        while let source:SymbolGraph = sources.popLast()
        {
            self.modules.append(source)

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
        guard dependencies.isEmpty, consumers.isEmpty 
        else 
        {
            fatalError("package contains dependency cycle")
        }
    }
}
