import URI 

extension Package 
{
    typealias _Pinned = Pinned 

    struct Pinned:Sendable 
    {
        let package:Package 
        let version:Version
        private 
        let fasces:Fasces 
        
        private 
        init(_ package:Package, version:Version, fasces:Fasces)
        {
            self.package = package
            self.version = version
            self.fasces = fasces
        }
        init(_ package:Package, version:Version)
        {
            self.init(package, version: version, fasces: package.tree.fasces(through: version))
        }

        var branch:Branch 
        {
            self.package.tree[self.version.branch]
        }
        var revision:Branch.Revision 
        {
            self.package.tree[self.version]
        }
        var selector:Version.Selector?
        {
            self.package.tree.abbreviate(self.version)
        }

        var nationality:Packages.Index 
        {
            self.package.nationality
        }

        var articles:Fasces.ArticleView
        {
            self.fasces.articles
        }
        var symbols:Fasces.SymbolView
        {
            self.fasces.symbols
        }
        var modules:Fasces.ModuleView
        {
            self.fasces.modules
        }
        var routes:Fasces.RoutingView 
        {
            self.fasces.routes
        }

        mutating 
        func repin(to version:Version) 
        {
            if version != self.version
            {
                self = .init(self.package, version: version)       
            }
        }
    }
}

extension Package.Pinned 
{
    func repinned(to version:Version) -> Self 
    {
        var repinned:Self = self 
            repinned.repin(to: version)
        return repinned
    }
    func repinned(to revisions:[Version.Revision], of branch:Branch, 
        _ body:(Self) throws -> ()) rethrows 
    {
        let trunk:Fasces? = branch.fork.map(self.package.tree.fasces(through:))
        for revision:Version.Revision in revisions 
        {
            let version:Version = .init(branch.index, revision)
            let fasces:Fasces
            if let trunk:Fasces 
            {
                fasces = .init([branch[...revision]] + trunk)
            }
            else 
            {
                fasces =       [branch[...revision]]
            }
            try body(.init(self.package, version: version, fasces: _move fasces))
        }
    }
}
extension Package.Pinned 
{
    func load(local article:Atom<Article>) -> Article?
    {
        assert(self.nationality == article.nationality)
        if let position:Atom<Article>.Position = article.positioned(bisecting: self.articles)
        {
            return self.package.tree[local: position]
        }
        else 
        {
            return nil
        }
    }
    func load(local symbol:Atom<Symbol>) -> Symbol?
    {
        assert(self.nationality == symbol.nationality)
        if let position:Atom<Symbol>.Position = symbol.positioned(bisecting: self.symbols)
        {
            return self.package.tree[local: position]
        }
        else 
        {
            return nil
        }
    }
    func load(local module:Atom<Module>) -> Module?
    {
        assert(self.nationality == module.nationality)
        if let position:Atom<Module>.Position = module.positioned(bisecting: self.modules)
        {
            return self.package.tree[local: position]
        }
        else 
        {
            return nil
        }
    }
}
extension Package.Pinned 
{
    func metadata(local article:Atom<Article>) -> Article.Metadata?
    {
        self.package.metadata.articles.value(of: .metadata(of: article), 
            in: self.fasces.articles) ?? nil
    }
    func metadata(local symbol:Atom<Symbol>) -> Symbol.Metadata?
    {
        self.package.metadata.symbols.value(of: .metadata(of: symbol), 
            in: self.fasces.symbols) ?? nil
    }
    func metadata(local module:Atom<Module>) -> Module.Metadata?
    {
        self.package.metadata.modules.value(of: .metadata(of: module), 
            in: self.fasces.modules) ?? nil
    }
    func metadata(foreign diacritic:Diacritic) -> Symbol.ForeignMetadata?
    {
        self.package.metadata.foreign.value(of: .metadata(of: diacritic), 
            in: self.fasces.foreign) ?? nil
    }
}
extension Package.Pinned 
{
    func exists(_ module:Atom<Module>) -> Bool
    {
        self.metadata(local: module) != nil
    }
    func exists(_ article:Atom<Article>) -> Bool
    {
        self.metadata(local: article) != nil 
    }
    func exists(_ symbol:Atom<Symbol>) -> Bool
    {
        self.metadata(local: symbol) != nil 
    }
    func exists(_ diacritic:Diacritic) -> Bool
    {
        self.metadata(foreign: diacritic) != nil 
    }
    func exists(_ composite:Composite) -> Bool
    {
        composite.compound.map(self.exists(_:)) ?? self.exists(composite.base)
    }
    func exists(_ compound:Compound) -> Bool 
    {
        self.nationality == compound.host.nationality ?
            self.metadata(local: compound.host)?
                .contains(feature: compound) ?? false :
            self.metadata(foreign: compound.diacritic)?
                .contains(feature: compound.base) ?? false
    }
}
extension Package.Pinned 
{
    func excavate(_ module:Atom<Module>) -> Version? 
    {
        self.package.metadata.modules.latestVersion(of: .metadata(of: module), 
            in: self.fasces.modules)
        {
            $0 != nil 
        }
    }
    func excavate(_ article:Atom<Article>) -> Version? 
    {
        self.package.metadata.articles.latestVersion(of: .metadata(of: article), 
            in: self.fasces.articles)
        {
            $0 != nil 
        }
    }
    func excavate(_ symbol:Atom<Symbol>) -> Version? 
    {
        self.package.metadata.symbols.latestVersion(of: .metadata(of: symbol), 
            in: self.fasces.symbols)
        {
            $0 != nil 
        }
    }
    func excavate(_ composite:Composite) -> Version? 
    {
        composite.compound.map(self.excavate(_:)) ?? self.excavate(composite.base)
    }
    func excavate(_ compound:Compound) -> Version? 
    {
        self.nationality == compound.host.nationality ?
            self.package.metadata.symbols.latestVersion(of: .metadata(of: compound.host), 
                in: self.fasces.symbols)
            {
                $0?.contains(feature: compound) ?? false 
            }
            :
            self.package.metadata.foreign.latestVersion(of: .metadata(of: compound.diacritic), 
                in: self.fasces.foreign)
            {
                $0?.contains(feature: compound.base) ?? false 
            }
    }
}

extension Package.Pinned 
{
    func resolve(_ link:_SymbolLink, scope:_Scope?, stems:Route.Stems, 
        where predicate:(Composite) throws -> Bool) 
        rethrows -> _SymbolLink.Resolution?
    {
        if  let resolution:_SymbolLink.Resolution = try self.resolve(exactly: link, 
                scope: scope, 
                stems: stems, 
                where: predicate)
        {
            return resolution 
        }
        if  let link:_SymbolLink = link.outed, 
            let resolution:_SymbolLink.Resolution = try self.resolve(exactly: link, 
                scope: scope, 
                stems: stems, 
                where: predicate)
        {
            return resolution
        }
        else 
        {
            return nil 
        }
    }
    private 
    func resolve(exactly link:_SymbolLink, scope:_Scope?, stems:Route.Stems, 
        where predicate:(Composite) throws -> Bool) 
        rethrows -> _SymbolLink.Resolution?
    {
        if  let scope:_Scope, 
            let selection:_Selection<Composite> = try scope.scan(concatenating: link, 
                stems: stems, 
                until: { try self.routes.select($0, where: predicate) })
        {
            return .init(selection)
        }
        guard let namespace:Atom<Module>.Position = self.fasces.modules.find(.init(link.first))
        else 
        {
            return nil
        }
        guard let link:_SymbolLink = link.suffix
        else 
        {
            return .module(namespace.atom)
        }
        if  let key:Route = stems[namespace.atom, link], 
            let selection:_Selection<Composite> = try self.routes.select(key, 
                where: predicate)
        {
            return .init(selection)
        }
        else 
        {
            return nil
        }
    }
}

extension Package.Pinned 
{
    func documentation() -> DocumentationExtension<Never>?
    {
        fatalError("unimplemented")
    }

    func documentation(for symbol:Atom<Symbol>) -> DocumentationExtension<Atom<Symbol>>?
    {
        self.package.data.symbolDocumentation.value(of: .documentation(of: symbol),
            in: self.fasces.symbols)
    }
    func documentation(for article:Atom<Article>) -> DocumentationExtension<Never>?
    {
        self.package.data.standaloneDocumentation.value(of: .documentation(of: article),
            in: self.fasces.articles)
    }
    func documentation(for module:Atom<Module>) -> DocumentationExtension<Never>?
    {
        self.package.data.standaloneDocumentation.value(of: .documentation(of: module),
            in: self.fasces.modules)
    }
    
    func topLevelSymbols(of module:Atom<Module>) -> Set<Atom<Symbol>>?
    {
        self.package.data.topLevelSymbols.value(of: .topLevelSymbols(of: module),
            in: self.fasces.modules)
    }
    func topLevelArticles(of module:Atom<Module>) -> Set<Atom<Article>>?
    {
        self.package.data.topLevelArticles.value(of: .topLevelArticles(of: module),
            in: self.fasces.modules)
    }

    func declaration(for symbol:Atom<Symbol>) -> Declaration<Atom<Symbol>>?
    {
        self.package.data.declarations.value(of: .declaration(of: symbol),
            in: self.fasces.symbols)
    }
    
    @available(*, deprecated, renamed: "exists(_:)")
    func contains(_ composite:Composite) -> Bool 
    {
        self.exists(composite)
    }
}

extension Package.Pinned 
{
    // /// Returns the address of the specified module, assuming it is local to this package.
    // func address(of module:Atom<Module>) -> Address?
    // {
    //     self.load(local: module).map { .init(residency: self, namespace: $0) }
    // }

    // /// Returns the address of the specified article, assuming it is local to this package.
    // func address(of article:Atom<Article>) -> Address?
    // {
    //     if  let namespace:Module = self.load(local: article.culture),
    //         let article:Article = self.load(local: article)
    //     {
    //         return .init(residency: self, namespace: namespace, article: article)
    //     }
    //     else 
    //     {
    //         return nil 
    //     }
    // }

    /// Returns the address of the specified composite, if all of its components 
    /// are defined in the provided context.
    func address(of composite:Composite,
        disambiguate:Address.DisambiguationLevel = .minimally, 
        context:some PackageContext) -> Address?
    {
        if let compound:Compound = composite.compound 
        {
            return self.address(of: compound, 
                disambiguate: disambiguate, 
                context: context)
        }
        else 
        {
            return self.address(of: composite.base, 
                disambiguate: disambiguate, 
                context: context)
        }
    }
    func address(of atomic:Atom<Symbol>,
        disambiguate:Address.DisambiguationLevel = .minimally, 
        context:some PackageContext) -> Address?
    {
        if let symbol:Symbol = self.load(local: atomic)
        {
            return self.address(of: atomic, symbol: symbol, 
                disambiguate: disambiguate, 
                context: context)
        }
        else 
        {
            return nil
        }
    }
    func address(of compound:Compound,
        disambiguate:Address.DisambiguationLevel = .minimally, 
        context:some PackageContext) -> Address?
    {
        if  let host:Symbol = context.load(compound.host), 
            let base:Symbol = context.load(compound.base)
        {
            return self.address(of: compound, host: host, base: base, 
                disambiguate: disambiguate, 
                context: context)
        }
        else 
        {
            return nil
        }
    }

    /// atomic addresses still require a full context, because they can still 
    /// migrate across namespaces.
    func address(of atomic:Atom<Symbol>, symbol:Symbol,
        disambiguate:Address.DisambiguationLevel = .minimally, 
        context:some PackageContext) -> Address?
    {
        assert(self.nationality == atomic.nationality)

        var address:Address.Symbolic = .init(path: symbol.path, orientation: symbol.orientation)
        switch disambiguate 
        {
        case .never: 
            break 
        
        case .minimally:
            switch self.depth(of: symbol.route, atomic: atomic)
            {
            case nil: 
                break 
            case .base?: 
                address.base = symbol.id 
            }
        
        case .maximally:
            address.base = symbol.id 
        }
        
        if  symbol.namespace.nationality != atomic.nationality 
        {
            address.nationality = .init(id: self.package.id, version: self.selector)
        }

        return .init(address, namespace: symbol.namespace, context: context)
    }
    func address(of compound:Compound, host:Symbol, base:Symbol,
        disambiguate:Address.DisambiguationLevel = .minimally, 
        context:some PackageContext) -> Address?
    {
        assert(self.nationality == compound.nationality)

        guard let stem:Route.Stem = host.kind.path
        else 
        {
            return nil 
        }

        var path:Path = host.path 
            path.append(base.name)
        
        var address:Address.Symbolic = .init(path: _move path, orientation: base.orientation)
        switch disambiguate 
        {
        case .never: 
            break 
        
        case .minimally:
            switch self.depth(of: .init(host.namespace, stem, base.route.leaf), 
                compound: compound)
            {
            case nil: 
                break 
            case .base?: 
                address.base = base.id 
            case .host?:
                address.base = base.id 
                address.host = host.id 
            }
        
        case .maximally:
            address.base = base.id 
            address.host = host.id 
        }
        
        if  host.namespace.nationality != compound.nationality 
        {
            address.nationality = .init(id: self.package.id, version: self.selector)
        }

        return .init(address, namespace: host.namespace, context: context)
    }
}

extension Branch 
{
    enum AtomicDepth:Error 
    {
        case base 
    }
    enum CompoundDepth:Error 
    {
        case base 
        case host 
    }
}
extension Package.Pinned 
{
    private 
    func depth(of route:Route, atomic:Atom<Symbol>) -> Branch.AtomicDepth?
    {
        do 
        {
            try self.routes.select(route) 
            {
                guard self.exists($0)
                else 
                {
                    return () 
                }
                if $0.base != atomic 
                {
                    throw Branch.AtomicDepth.base 
                }
            } as ()
            return nil  
        }
        catch 
        {
            return .base
        }
    }
    private 
    func depth(of route:Route, compound:Compound) -> Branch.CompoundDepth?
    {
        do 
        {
            var depth:Branch.CompoundDepth? = nil
            try self.routes.select(route) 
            {
                guard self.exists($0)
                else 
                {
                    return () 
                }
                if $0.base != compound.base 
                {
                    depth = .base 
                }
                else if case compound.host? = $0.host
                {
                    return ()
                }
                else 
                {
                    throw Branch.CompoundDepth.host
                }
            } as ()
            return depth 
        }
        catch 
        {
            return .host 
        }
    }
}
