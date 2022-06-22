extension Ecosystem 
{
    func location(of index:Package.Index, at version:Version) 
        -> Link.Reference<[String]>
    {
        let package:Package = self[index]
        
        var location:Link.Reference<[String]> = .init(path: [package.name])
        if let version:MaskedVersion = package.versions.abbreviate(version)
        {
            location.path.append(version.description)
        }
        return location
    }
    
    func location(of index:Module.Index, at version:Version) 
        -> Link.Reference<[String]>
    {
        let package:Package = self[index.package]
        
        var location:Link.Reference<[String]> = package.root
        if let version:MaskedVersion = package.versions.abbreviate(version)
        {
            location.path.append(version.description)
        }
        // *not* `id.string` !
        location.path.append(package[local: index].id.value)
        return location
    }
    
    func location(of index:Article.Index, at version:Version) 
        -> Link.Reference<[String]>
    {
        var location:Link.Reference<[String]> = 
            self.location(of: index.module, at: version)
        for component:String in self[index].path 
        {
            location.path.append(component.lowercased())
        }
        return location
    }
    
    func location(of composite:Symbol.Composite, at version:Version, group:Bool = false) 
        -> Link.Reference<[String]>
    {
        let culture:Package = self[composite.culture.package]
        // same as host if composite is natural
        let base:Symbol = self[composite.base]
        let host:Symbol = self[composite.diacritic.host] 
        
        var location:Link.Reference<[String]> = self[host.namespace.package].root
        if  culture.index == host.namespace.package, 
            let version:MaskedVersion = culture.versions.abbreviate(version)
        {
            location.path.append(version.description)
        }
        
            location.path.append(self[host.namespace].id.value)
        
        for component:String in host.path 
        {
            location.path.append(component.lowercased())
        }
        
        if !group 
        {
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
        }
        
        location.orientation = base.orientation
        
        if composite.culture.package != host.namespace.package
        {
            location.query.lens = (culture.id, culture.versions.abbreviate(version))
        }
        return location
    }
}
