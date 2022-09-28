// this isn’t *quite* ``SurfaceBuilder.Context``, because ``local`` is pinned here.
struct AnisotropicContext:Sendable 
{
    let upstream:[Package.Index: Package.Pinned]
    var local:Package.Pinned 

    init(local:Package.Index, version:Version, context:__shared Packages)
    {
        self.init(local: .init(context[local], version: version), context: context)
    }
    init(local:Package.Pinned, context:__shared Packages)
    {
        self.init(local: local, pins: local.revision.pins, 
            context: context)
    }
    init(local:Package.Pinned, metadata:__shared Module.Metadata, 
        context:__shared Packages)
    {
        let filter:Set<Package.Index> = .init(metadata.dependencies.lazy.map(\.nationality))
        self.init(local: local, 
            pins: local.revision.pins.filter { filter.contains($0.key) }, 
            context: context)
    }
    init(local:Package.Pinned, pins:__shared [Package.Index: Version], 
        context:__shared Packages)
    {
        self.local = local 
        var upstream:[Package.Index: Package.Pinned] = .init(minimumCapacity: pins.count)
        for (index, version):(Package.Index, Version) in pins 
        {
            upstream[index] = .init(context[index], version: version)
        }
        self.upstream = upstream
    }
}
extension AnisotropicContext 
{
    func repinned(to version:Version, context:__shared Packages) -> Self 
    {
        .init(local: self.local.repinned(to: version), context: context)
    }
}
extension AnisotropicContext:PackageContext
{
    subscript(nationality:Package.Index) -> Package.Pinned?
    {
        _read 
        {
            yield   self.local.nationality == nationality ? 
                    self.local : self.upstream[nationality]
        }
    }
}
// extension AnisotropicContext
// {
//     func address(local composite:Composite, 
//         disambiguate:Address.DisambiguationLevel = .minimally) -> Address?
//     {
//         self.local.address(of: composite, disambiguate: disambiguate, context: self)
//     }
// }
extension AnisotropicContext
{
    func find(_ id:Symbol.ID, linked:Set<Atom<Module>>) -> (Atom<Symbol>.Position, Symbol)?
    {
        if  let position:Atom<Symbol>.Position = self.local.symbols.find(id), 
                linked.contains(position.culture)
        {
            return (position, self.local.package.tree[local: position]) 
        }
        for upstream:Package.Pinned in self.upstream.values 
        {
            if  let position:Atom<Symbol>.Position = upstream.symbols.find(id), 
                    linked.contains(position.culture)
            {
                return (position, upstream.package.tree[local: position])
            }
        }
        return nil
    }
}