import Versions

extension Package 
{
    struct Pinned:Sendable 
    {
        let package:Package 
        let version:Version
        // exhibited version can be different from true version, due to 
        // implementation of historical pages. this is only used by the top-level 
        // url redirection system, content links do not use exhibitions
        let exhibit:Version?
        
        init(_ package:Package, at version:Version, exhibit:Version? = nil)
        {
            self.version = version  
            self.package = package
            self.exhibit = exhibit
        }
    }
}
extension Package.Pinned 
{
    private 
    var abbreviatedVersion:MaskedVersion? 
    {
        self.package.versions.abbreviate(self.exhibit ?? self.version)
    }
    
    private 
    func depth(of composite:Branch.Composite, route:Route.Key) -> (host:Bool, base:Bool)
    {
        self.package.depth(of: composite, at: self.version, route: route)
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
            query.lens = .init(self.package.id, at: self.abbreviatedVersion)
        }
        return query
    }
}
extension Package.Pinned 
{
    func documentation() -> DocumentationNode
    {
        self.package.documentation[self.package.heads.documentation]
            .at(self.version) ?? 
            .extends(nil, with: .init())
    }
    func documentation(_ module:Module.Index) -> DocumentationNode
    {
        self.package.documentation[self.package[local: module].heads.documentation]
            .at(self.version) ?? 
            .extends(nil, with: .init())
    }
    func documentation(_ symbol:Symbol.Index) -> DocumentationNode
    {
        self.package.documentation[self.package[local: symbol].heads.documentation]
            .at(self.version) ?? 
            .extends(nil, with: .init())
    }
    func documentation(_ article:Article.Index) -> DocumentationNode
    {
        self.package.documentation[self.package[local: article].heads.documentation]
            .at(self.version) ?? 
            .extends(nil, with: .init())
    }
    func excerpt(_ article:Article.Index) -> Article.Excerpt
    {
        self.package.excerpts[self.package[local: article].heads.excerpt]
            .at(self.version) ?? 
            .init("Untitled")
    }
    
    func dependencies(_ module:Module.Index) -> Set<Module.Index>
    {
        // `nil` case should be unreachable in practice
        self.package.dependencies[self.package[local: module].heads.dependencies]
            .at(self.version) ?? []
    }
    func toplevel(_ module:Module.Index) -> Set<Symbol.Index>
    {
        // `nil` case should be unreachable in practice
        self.package.toplevels[self.package[local: module].heads.toplevel]
            .at(self.version) ?? []
    }
    func guides(_ module:Module.Index) -> Set<Article.Index>
    {
        self.package.guides[self.package[local: module].heads.guides]
            .at(self.version) ?? []
    }
    
    func declaration(_ symbol:Symbol.Index) -> Declaration<Symbol.Index>
    {
        // `nil` case should be unreachable in practice
        self.package.declarations[self.package[local: symbol].heads.declaration]
            .at(self.version) ?? 
            .init(fallback: "<unavailable>")
    }
    func facts(_ symbol:Symbol.Index) -> Symbol.Predicates<Symbol.Index> 
    {
        // `nil` case should be unreachable in practice
        self.package.facts[self.package[local: symbol].heads.facts]
            .at(self.version) ?? 
            .init(roles: nil)
    }
    
    func contains(_ composite:Branch.Composite) -> Bool 
    {
        self.package.contains(composite, at: self.version)
    }
}
