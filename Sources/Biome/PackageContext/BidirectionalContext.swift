struct BidirectionalContext:AnisotropicContext, Sendable
{
    struct Consumer 
    {
        let pinned:Package.Pinned 
        let modules:Set<Atom<Module>>

        var nationality:Packages.Index 
        {
            self.pinned.nationality
        }
    }

    private(set)
    var dependencies:[Package.Pinned],
        consumers:[Consumer]
    private(set)
    var foreign:[Packages.Index: Package.Pinned]
    let local:Package.Pinned 
    
    init(local:Package.Pinned, context:__shared Packages) 
    {
        let revision:Branch.Revision = local.revision
        self.local = local
        self.foreign = .init(minimumCapacity: revision.pins.count)
        self.dependencies = []
        for (index, version):(Packages.Index, Version) in revision.pins 
        {
            let dependency:Package.Pinned = .init(context[index], version: version)
            self.dependencies.append(dependency)
            self.foreign[index] = dependency
        }
        self.consumers = []
        for (index, versions):(Packages.Index, [Version: Set<Atom<Module>>]) in 
            revision.consumers
        {
            let consumer:Package = context[index]
            if  let version:Version = consumer.tree.default, 
                let modules:Set<Atom<Module>> = versions[version], 
                self.local.package.settings.whitelist?.contains(consumer.id) ?? true 
            {
                let consumer:Package.Pinned = .init(consumer, version: version)
                self.consumers.append(.init(pinned: consumer, modules: modules))
                self.foreign[index] = consumer
            }
        }
    }
}
