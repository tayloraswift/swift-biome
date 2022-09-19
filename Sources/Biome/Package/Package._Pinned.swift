import URI 

struct _Scope 
{
    let namespace:Atom<Module>
    let path:[String]

    init(_ namespace:Atom<Module>, _ path:[String] = [])
    {
        self.namespace = namespace 
        self.path = path
    }
    init(_ symbol:__shared Symbol)
    {
        switch symbol.orientation 
        {
        case .gay:
            self.init(symbol.namespace,       symbol.path.prefix)
        case .straight:
            self.init(symbol.namespace, .init(symbol.path))
        }
    }

    func scan<T>(concatenating link:_SymbolLink, stems:Route.Stems, 
        until match:(Route) throws -> T?) rethrows -> T?
    {
        for level:Int in self.path.indices.reversed()
        {
            if  let key:Route = 
                    stems[self.namespace, self.path.prefix(through: level), link],
                let match:T = try match(key)
            {
                return match
            }
        }
        return try stems[self.namespace, link].flatMap(match)
    }
}

extension [Package.Index: Package._Pinned] 
{
    mutating 
    func update(with pinned:__owned Package._Pinned) 
    {
        self[pinned.nationality] = pinned
    }
}

extension Package 
{
    typealias _Pinned = Pinned 

    struct Pinned:Sendable 
    {
        let package:Package 
        let version:Version
        private 
        let fasces:Fasces 
        
        init(_ package:Package, version:Version)
        {
            self.package = package
            self.version = version
            self.fasces = self.package.tree.fasces(through: self.version)
        }

        var nationality:Package.Index 
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
    }
}

extension Package.Pinned 
{
    func load(local article:Atom<Article>) -> Article?
    {
        if let position:PluralPosition<Article> = article.pluralized(bisecting: self.articles)
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
        if let position:PluralPosition<Symbol> = symbol.pluralized(bisecting: self.symbols)
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
        if let position:PluralPosition<Module> = module.pluralized(bisecting: self.modules)
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
        self.package.metadata.articles.value(of: article, 
            field: (\.metadata, \.metadata), 
            in: self.fasces.articles) ?? nil
    }
    func metadata(local symbol:Atom<Symbol>) -> Symbol.Metadata?
    {
        self.package.metadata.symbols.value(of: symbol, 
            field: (\.metadata, \.metadata), 
            in: self.fasces.symbols) ?? nil
    }
    func metadata(local module:Atom<Module>) -> Module.Metadata?
    {
        self.package.metadata.modules.value(of: module, 
            field: (\.metadata, \.metadata), 
            in: self.fasces.modules) ?? nil
    }
    func metadata(foreign diacritic:Diacritic) -> Symbol.ForeignMetadata?
    {
        self.package.metadata.foreign.value(of: diacritic, 
            field: \.metadata, 
            in: self.fasces.foreign) ?? nil
    }
}
extension Package.Pinned 
{
    func exists(_ article:Atom<Article>) -> Bool
    {
        self.metadata(local: article) != nil 
    }
    func exists(_ symbol:Atom<Symbol>) -> Bool
    {
        self.metadata(local: symbol) != nil 
    }
    func exists(_ module:Atom<Module>) -> Bool
    {
        self.metadata(local: module) != nil
    }
    func exists(_ diacritic:Diacritic) -> Bool
    {
        self.metadata(foreign: diacritic) != nil 
    }
    func exists(_ composite:Composite) -> Bool
    {
        guard let compound:Compound = composite.compound
        else 
        {
            return self.exists(composite.base)
        }
        if self.nationality == compound.host.nationality
        {
            return self.metadata(local: compound.host)?
                .contains(feature: compound) ?? false
        }
        else 
        {
            return self.metadata(foreign: compound.diacritic)?
                .contains(feature: compound.base) ?? false
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
        guard let namespace:PluralPosition<Module> = self.fasces.modules.find(.init(link.first))
        else 
        {
            return nil
        }
        guard let link:_SymbolLink = link.suffix
        else 
        {
            return .module(namespace.contemporary)
        }
        if  let key:Route = stems[namespace.contemporary, link], 
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
    func documentation() -> DocumentationExtension<Never>
    {
        fatalError("unimplemented")
    }

    func documentation(for symbol:Atom<Symbol>) 
        -> DocumentationExtension<Atom<Symbol>>
    {
        self.package.data.symbolDocumentation.value(of: symbol, 
            field: (\.documentation, \.documentation), 
            in: self.fasces.symbols) ?? .init()
    }
    func documentation(for article:Atom<Article>) -> DocumentationExtension<Never>
    {
        self.package.data.standaloneDocumentation.value(of: article, 
            field: (\.documentation, \.documentation), 
            in: self.fasces.articles) ?? .init()
    }
    func documentation(for module:Atom<Module>) -> DocumentationExtension<Never>
    {
        self.package.data.standaloneDocumentation.value(of: module, 
            field: (\.documentation, \.documentation), 
            in: self.fasces.modules) ?? .init()
    }
    
    func topLevelSymbols(of module:Atom<Module>) -> Set<Atom<Symbol>>
    {
        self.package.data.topLevelSymbols.value(of: module, 
            field: (\.topLevelSymbols, \.topLevelSymbols), 
            in: self.fasces.modules) ?? []
    }
    func topLevelArticles(of module:Atom<Module>) -> Set<Atom<Article>>
    {
        self.package.data.topLevelArticles.value(of: module, 
            field: (\.topLevelArticles, \.topLevelArticles), 
            in: self.fasces.modules) ?? []
    }

    func declaration(for symbol:Atom<Symbol>) -> Declaration<Atom<Symbol>>
    {
        self.package.data.declarations.value(of: symbol, 
            field: (\.declaration, \.declaration), 
            in: self.fasces.symbols) ?? .init(fallback: "<unavailable>")
    }
    
    @available(*, deprecated, renamed: "exists(_:)")
    func contains(_ composite:Composite) -> Bool 
    {
        self.exists(composite)
    }
}

extension Package.Pinned 
{
    /// Returns the address of the specified package, if it is defined in this context.
    /// 
    /// The returned address always includes the package name, even if it is the 
    /// standard library or one of the core libraries.
    func address(function:Service.Function = .documentation(.symbol)) -> Address
    {
        return .init(function: .documentation(.symbol), global: .init(
            residency: self.package.id, 
            version: self.package.tree.abbreviate(self.version)))
    }
    /// Returns the address of the specified module, assuming it is local to this package.
    func address(local module:Atom<Module>) -> Address?
    {
        self.load(local: module).map(self.address(of:))
    }
    func address(of module:Module) -> Address
    {
        let global:Address.Global = .init(
            residency: module.nationality.isCommunityPackage ? self.package.id : nil, 
            version: self.package.tree.abbreviate(self.version), 
            local: .init(namespace: module.id))
        return .init(function: .documentation(.symbol), global: _move global)
    }
    /// Returns the address of the specified article, assuming it is local to this package.
    func address(local article:Atom<Article>) -> Address?
    {
        if  let namespace:Module = self.load(local: article.culture),
            let article:Article = self.load(local: article)
        {
            return self.address(of: article, namespace: namespace)
        }
        else 
        {
            return nil 
        }
    }
    func address(of article:Article, namespace:Module) -> Address
    {
        let local:Address.Local = .init(namespace: namespace.id, 
            symbolic: .init(path: article.path, orientation: .straight))
        let global:Address.Global = .init(
            residency: namespace.nationality.isCommunityPackage ? self.package.id : nil, 
            version: self.package.tree.abbreviate(self.version), 
            local: _move local)
        return .init(function: .documentation(.doc), global: _move global)
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
    func depth(of route:Route, atom:Atom<Symbol>) -> Branch.AtomicDepth?
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
                if $0.base != atom 
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
// extension Package._Pinned 
// {
//     func _all() 
//     {
//         let modules:Set<Atom<Module>> = self._allModules()
//         for epoch:Epoch<Module> in self.fasces.modules 
//         {
//             for (module, divergence):(Atom<Module>, Module.Divergence) in 
//                 epoch.divergences
//             {
//                 for (range, _):(Range<Symbol.Offset>, Atom<Module>) in divergence.symbols 
//                 {
//                     for offset:Symbol.Offset in range 
//                     {
//                         self.missingSymbols.insert(.init(module, offset: offset))
//                     }
//                 }
//             }
//         }
//     }
//     func _allModules() -> Set<Atom<Module>>
//     {
//         var modules:Set<Atom<Module>> = []
//         for module:Module in self.fasces.modules.joined()
//         {
//             if self.exists(module.index)
//             {
//                 modules.insert(module.index)
//             }
//         }
//         return modules
//     }
// }