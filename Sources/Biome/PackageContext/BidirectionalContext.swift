struct BidirectionalContext:AnisotropicContext, Sendable
{
    struct Consumer 
    {
        let pinned:Package.Pinned 
        let modules:Set<Module>

        var nationality:Package 
        {
            self.pinned.nationality
        }
    }

    private(set)
    var dependencies:[Package.Pinned],
        consumers:[Consumer]
    private(set)
    var foreign:[Package: Package.Pinned]
    let local:Package.Pinned 
    
    init(local:Package.Pinned, context:__shared Package.Trees) 
    {
        let revision:Branch.Revision = local.revision
        self.local = local
        self.foreign = .init(minimumCapacity: revision.pins.count)
        self.dependencies = []
        for (index, version):(Package, Version) in revision.pins 
        {
            let dependency:Package.Pinned = .init(context[index], version: version)
            self.dependencies.append(dependency)
            self.foreign[index] = dependency
        }
        self.consumers = []
        for (index, versions):(Package, [Version: Set<Module>]) in 
            revision.consumers
        {
            let consumer:Package.Tree = context[index]
            if  let version:Version = consumer.default, 
                let modules:Set<Module> = versions[version], 
                self.local.tree.settings.whitelist?.contains(consumer.id) ?? true 
            {
                let consumer:Package.Pinned = .init(consumer, version: version)
                self.consumers.append(.init(pinned: consumer, modules: modules))
                self.foreign[index] = consumer
            }
        }
    }
}
