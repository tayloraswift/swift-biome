extension Biome 
{
    func canonical(_ target:Link.Target) -> Link.Reference<[Link.Component]>
    {
        switch target 
        {
        case .composite(let composite):
            //return self.canonical(composite)
            fatalError("unimplemented")
        case .module(let module):
            return self.canonical(module)
        default: 
            fatalError("unimplemented")
        }
    }
    private 
    func canonical(_ index:Module.Index) -> Link.Reference<[Link.Component]>
    {
        var canonical:Link.Reference<[Link.Component]> = .init(path: [])
            canonical.path.reserveCapacity(2)
        
        canonical.append(lowercasing: self.prefixes.master)
        
        let module:Module = self.ecosystem[index]
        let package:Package = self.ecosystem[index.package]
        switch package.kind 
        {
        case .swift: 
            break 
        case .core, .community(_): 
            canonical.append(package.id)
        }
        canonical.append(module.id)
        return canonical
    }
    /* private 
    func canonical(_ composite:Symbol.Composite) -> Link.Reference<[Link.Component]>
    {
        var canonical:Link.Reference<[Link.Component]>
        
        let base:Symbol = self.ecosystem[composite.base]
        if  let victim:Symbol.Index = composite.victim 
        {
            let victim:Symbol = self.ecosystem[victim]
            canonical = self.canonical(victim.namespace)
            canonical.append(contentsOf: victim.path)
            // not necessarily the same as the base’s culture!
            self.ecosystem[composite.culture.package].victims
        }
        else 
        {
            canonical = self.canonical(base.namespace)
            canonical.append(contentsOf: base.path.prefix)
        }
        canonical.append(oriented: base)
    } */
}
