import Versions

extension Package.Pinned
{
    // exhibited version can be different from true version, due to 
    // implementation of historical pages. this is only used by the top-level 
    // url redirection system, content links do not use exhibitions
    @available(*, deprecated)
    var exhibit:Version?
    {
        nil 
    }
    
    @available(*, deprecated)
    init(_ package:Package, at version:Version, exhibit:Version? = nil)
    {
        fatalError("obsoleted")
    }
}
extension Package.Pinned 
{
    private 
    var abbreviatedVersion:MaskedVersion? 
    {
        fatalError("unimplemented")
        //self.package.tree.abbreviate(self.exhibit ?? self.version)
    }
    
    var prefix:[String]
    {
        self.package.prefix(arrival: self.abbreviatedVersion)
    }
    var path:[String]
    {
        if let version:MaskedVersion = self.abbreviatedVersion
        {
            return [self.package.name, version.description]
        }
        else 
        {
            return [self.package.name]
        }
    }
    func path(to composite:Branch.Composite, ecosystem:Ecosystem) -> [String]
    {
        // same as host if composite is natural
        let base:Symbol = ecosystem[composite.base]
        let host:Symbol = ecosystem[composite.diacritic.host] 
        let residency:Package.Index = host.namespace.package 
        let arrival:MaskedVersion? = 
            composite.culture.package == residency ? self.abbreviatedVersion : nil
        var path:[String] = ecosystem[residency].prefix(arrival: arrival)
        
            path.append(ecosystem[host.namespace].id.value)
        
        for component:String in host.path 
        {
            path.append(component.lowercased())
        }
        if composite.base != composite.diacritic.host
        {
            path.append(base.name.lowercased())
        }
        return path
    }
    func query(to composite:Branch.Composite, ecosystem:Ecosystem) -> Symbol.Link.Query
    {
        // same as host if composite is natural
        let base:Symbol = ecosystem[composite.base]
        let host:Symbol = ecosystem[composite.diacritic.host] 

        var query:Symbol.Link.Query = .init()
        if composite.base != composite.diacritic.host
        {
            guard let stem:Route.Stem = host.kind.path
            else 
            {
                fatalError("unreachable: (host: \(host), base: \(base))")
            }
            
            let route:Route.Key = .init(host.namespace, stem, base.route.leaf)
            switch self.depth(of: composite, route: route)
            {
            case nil: 
                break 
            
            case .host?: 
                query.host = host.id
                fallthrough 
                
            case .base?: 
                query.base = base.id
            }
        }
        else 
        {
            switch self.depth(of: composite, route: base.route)
            {
            case nil: 
                break 
            case _?: 
                query.base = base.id
            }
        }
        
        if composite.culture.package != host.namespace.package
        {
            query.lens = .init(self.package.id, at: self.abbreviatedVersion)
        }
        return query
    }
}