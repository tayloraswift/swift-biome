extension Package 
{
    struct Pinned:Sendable 
    {
        let package:Package 
        let version:Version
        
        init(_ package:Package, at version:Version)
        {
            self.version = version  
            self.package = package
        }
    }
}
extension Package.Pinned 
{
    private 
    var abbreviatedVersion:MaskedVersion? 
    {
        self.package.versions.abbreviate(self.version)
    }
    
    private 
    func depth(of composite:Symbol.Composite, route:Route) -> (host:Bool, base:Bool)
    {
        self.package.depth(of: composite, at: self.version, route: route)
    }
    
    func path() -> [String]
    {
        var path:[String] = [self.package.name]
        if let version:MaskedVersion = self.abbreviatedVersion
        {
            path.append(version.description)
        }
        return path
    }
    func path(to index:Module.Index) -> [String]
    {
        var path:[String] = self.package.trunk
        if let version:MaskedVersion = self.abbreviatedVersion
        {
            path.append(version.description)
        }
        // *not* `id.string` !
        path.append(self.package[local: index].id.value)
        return path
    }
    func path(to index:Article.Index) -> [String]
    {
        var path:[String] = self.path(to: index.module)
        for component:String in self.package[local: index].path 
        {
            path.append(component.lowercased())
        }
        return path
    }
    func path(to composite:Symbol.Composite, ecosystem:Ecosystem) -> [String]
    {
        // same as host if composite is natural
        let base:Symbol = ecosystem[composite.base]
        let host:Symbol = ecosystem[composite.diacritic.host] 
        
        var path:[String] = ecosystem[host.namespace.package].trunk
        if  composite.culture.package == host.namespace.package, 
            let version:MaskedVersion = self.abbreviatedVersion
        {
            path.append(version.description)
        }
        
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
    func query(to composite:Symbol.Composite, ecosystem:Ecosystem) -> Symbol.Link.Query
    {
        // same as host if composite is natural
        let base:Symbol = ecosystem[composite.base]
        let host:Symbol = ecosystem[composite.diacritic.host] 

        var query:Symbol.Link.Query = .init()
        if composite.base != composite.diacritic.host
        {
            guard let stem:Stem = host.kind.path
            else 
            {
                fatalError("unreachable: (host: \(host), base: \(base))")
            }
            
            let route:Route = .init(host.namespace, stem, base.route.leaf)
            switch self.depth(of: composite, route: route)
            {
            case (host: false, base: false): 
                break 
            
            case (host: true,  base: _): 
                query.host = host.id
                fallthrough 
                
            case (host: false, base: true): 
                query.base = base.id
            }
        }
        else 
        {
            switch self.depth(of: composite, route: base.route)
            {
            case (host: _, base: false): 
                break 
            case (host: _, base: true): 
                query.base = base.id
            }
        }
        
        if composite.culture.package != host.namespace.package
        {
            query.lens = (self.package.id, self.abbreviatedVersion)
        }
        return query
    }
}
extension Package.Pinned 
{
    func template() -> Article.Template<Ecosystem.Link>
    {
        self.package.templates.at(self.version, head: self.package.heads.template) ?? 
            .init()
    }
    func template(_ module:Module.Index) -> Article.Template<Ecosystem.Link>
    {
        self.package.templates
            .at(self.version, head: self.package[local: module].heads.template) ?? 
            .init()
    }
    func template(_ symbol:Symbol.Index) -> Article.Template<Ecosystem.Link>
    {
        self.package.templates
            .at(self.version, head: self.package[local: symbol].heads.template) ?? 
            .init()
    }
    func template(_ article:Article.Index) -> Article.Template<Ecosystem.Link>
    {
        self.package.templates
            .at(self.version, head: self.package[local: article].heads.template) ?? 
            .init()
    }
    func headline(_ article:Article.Index) -> Article.Headline
    {
        self.package.headlines
            .at(self.version, head: self.package[local: article].heads.headline) ?? 
            .init("Untitled")
    }
    
    func dependencies(_ module:Module.Index) -> Set<Module.Index>
    {
        // `nil` case should be unreachable in practice
        self.package.dependencies
            .at(self.version, head: self.package[local: module].heads.dependencies) ?? []
    }
    func toplevel(_ module:Module.Index) -> Set<Symbol.Index>
    {
        // `nil` case should be unreachable in practice
        self.package.toplevels
            .at(self.version, head: self.package[local: module].heads.toplevel) ?? []
    }
    
    func declaration(_ symbol:Symbol.Index) -> Symbol.Declaration
    {
        // `nil` case should be unreachable in practice
        self.package.declarations
            .at(self.version, head: self.package[local: symbol].heads.declaration) ?? 
            .init(fallback: "<unavailable>")
    }
    func facts(_ symbol:Symbol.Index) -> Symbol.Predicates 
    {
        // `nil` case should be unreachable in practice
        self.package.facts
            .at(self.version, head: self.package[local: symbol].heads.facts) ?? 
            .init(roles: nil)
    }
    
    func contains(_ composite:Symbol.Composite) -> Bool 
    {
        self.package.contains(composite, at: self.version)
    }
}
