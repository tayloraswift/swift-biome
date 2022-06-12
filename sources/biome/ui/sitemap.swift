extension Biome 
{
    func uri(of index:Ecosystem.Index, at version:Version) -> URI
    {
        let prefix:String 
        let location:Link.Reference<[String]>
        switch index 
        {
        case .composite(let composite):
            prefix = self.prefixes.master
            location = self.ecosystem.location(of: composite, at: version)
        
        case .module(let module):
            prefix = self.prefixes.master
            location = self.ecosystem.location(of: module, at: version)
        
        default: 
            fatalError("unimplemented")
        }
        return .init(prefix: prefix, location)
    }
}

extension Ecosystem 
{
    fileprivate 
    func location(of namespace:Module.Index, at version:Version) 
        -> Link.Reference<[String]>
    {
        let package:Package = self[namespace.package]
        
        var location:Link.Reference<[String]> = package.root
        if let version:Version = package.abbreviate(version)
        {
            location.path.append(version.description)
        }
        // *not* `id.string` !
        location.path.append(self[namespace].id.value)
        return location
    }
    
    fileprivate 
    func location(of composite:Symbol.Composite, at version:Version) 
        -> Link.Reference<[String]>
    {
        // same as host if composite is natural
        let base:Symbol = self[composite.base]
        let host:Symbol = self[composite.diacritic.host] 
        
        var location:Link.Reference<[String]> = self[host.namespace.package].root
        
        let culture:Package = self[composite.culture.package]
        if  culture.index == host.namespace.package, 
            let version:Version = culture.abbreviate(version)
        {
            location.path.append(version.description)
        }
        
            location.path.append(self[host.namespace].id.value)
        
        for component:String in host.path 
        {
            location.path.append(component.lowercased())
        }
        
        if composite.base != composite.diacritic.host
        {
            location.path.append(base.name.lowercased())
            
            guard let stem:Route.Stem = host.kind.path
            else 
            {
                fatalError("unreachable: (host: \(host), base: \(base))")
            }
            
            let route:Route = .init(host.namespace, stem, base.route.leaf)
            switch culture.depth(of: composite, at: version, route: route)
            {
            case (host: false, base: false): 
                break 
            
            case (host: true,  base: _): 
                location.query.host = host.id
                fallthrough 
                
            case (host: false, base: true): 
                location.query.base = base.id
            }
        }
        else 
        {
            switch culture.depth(of: composite, at: version, route: base.route)
            {
            case (host: _, base: false): 
                break 
            case (host: _, base: true): 
                location.query.base = base.id
            }
        }
        
        location.orientation = base.orientation
        
        if composite.culture.package != host.namespace.package
        {
            location.query.lens = (culture.id, culture.latest != version ? version : nil)
        }
        return location
    }
}
