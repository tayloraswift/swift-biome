// this isn’t *quite* ``SurfaceBuilder.Context``, because ``local`` is pinned here.
struct DirectionalContext:AnisotropicContext, Sendable 
{
    private(set) 
    var foreign:[Package: Package.Pinned]
    let local:Package.Pinned 

    init(local:Package.Pinned, upstream:[Package: Package.Pinned])
    {
        self.foreign = upstream 
        self.local = local
    }
    init(local:Package.Pinned, pins:__shared [Package: Version], 
        context:__shared Package.Trees)
    {
        self.local = local 
        self.foreign = .init(minimumCapacity: pins.count)
        for (index, version):(Package, Version) in pins 
        {
            self.foreign[index] = .init(context[index], version: version)
        }
    }
}

extension DirectionalContext 
{
    init(local:Package.Pinned, context:__shared Package.Trees) 
    {
        self.init(local: local, pins: local.revision.pins, context: context)
    }
    init(local:Package.Pinned, metadata:__shared Module.Metadata, context:__shared Package.Trees) 
    {
        let filter:Set<Package> = .init(metadata.dependencies.lazy.map(\.nationality))
        self.init(local: local, 
            pins: local.revision.pins.filter { filter.contains($0.key) }, 
            context: context)
    }
}
extension DirectionalContext 
{
    func repinned(to version:Version, context:__shared Package.Trees) -> Self 
    {
        .init(local: self.local.repinned(to: version), context: context)
    }
}