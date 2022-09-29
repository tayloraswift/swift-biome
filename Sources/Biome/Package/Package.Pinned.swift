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
    func path(to composite:Composite, ecosystem:Ecosystem) -> [String]
    {
        // same as host if composite is natural
        let base:Symbol = ecosystem[composite.base]
        let host:Symbol = ecosystem[composite.diacritic.host] 
        let residency:Packages.Index = host.namespace.nationality 
        let arrival:MaskedVersion? = 
            composite.culture.nationality == residency ? self.abbreviatedVersion : nil
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
    func query(to composite:Composite, ecosystem:Ecosystem) -> Symbol.Link.Query
    {
        fatalError("obsoleted")
    }
}