import URI 

struct _Scope 
{
    let namespace:Branch.Position<Module>
    let path:[String]

    init(_ namespace:Branch.Position<Module>, _ path:[String] = [])
    {
        self.namespace = namespace 
        self.path = path
    }
    init(_ symbol:__shared Symbol)
    {
        switch symbol.orientation 
        {
        case .gay:
            self.init(symbol.namespace, symbol.path.prefix)
        case .straight:
            self.init(symbol.namespace, .init(symbol.path))
        }
    }

    func scan<T>(concatenating link:_SymbolLink, stems:Route.Stems, 
        until match:(Route.Key) throws -> T?) rethrows -> T?
    {
        for level:Int in self.path.indices.reversed()
        {
            if  let key:Route.Key = 
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
    func load(local article:Branch.Position<Article>) -> Article?
    {
        if let position:Tree.Position<Article> = article.pluralized(bisecting: self.articles)
        {
            return self.package.tree[local: position]
        }
        else 
        {
            return nil
        }
    }
    func load(local symbol:Branch.Position<Symbol>) -> Symbol?
    {
        if let position:Tree.Position<Symbol> = symbol.pluralized(bisecting: self.symbols)
        {
            return self.package.tree[local: position]
        }
        else 
        {
            return nil
        }
    }
    func load(local module:Branch.Position<Module>) -> Module?
    {
        if let position:Tree.Position<Module> = module.pluralized(bisecting: self.modules)
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
    func metadata(local article:Branch.Position<Article>) -> Article.Metadata?
    {
        self.package.metadata.articles.value(of: article, 
            field: (\.metadata, \.metadata), 
            in: self.fasces.articles) ?? nil
    }
    func metadata(local symbol:Branch.Position<Symbol>) -> Symbol.Metadata?
    {
        self.package.metadata.symbols.value(of: symbol, 
            field: (\.metadata, \.metadata), 
            in: self.fasces.symbols) ?? nil
    }
    func metadata(local module:Branch.Position<Module>) -> Module.Metadata?
    {
        self.package.metadata.modules.value(of: module, 
            field: (\.metadata, \.metadata), 
            in: self.fasces.modules) ?? nil
    }
    func metadata(foreign diacritic:Branch.Diacritic) -> Symbol.ForeignMetadata?
    {
        self.package.metadata.foreign.value(of: diacritic, 
            field: \.metadata, 
            in: self.fasces.foreign) ?? nil
    }
}
extension Package.Pinned 
{
    func exists(_ article:Branch.Position<Article>) -> Bool
    {
        self.metadata(local: article) != nil 
    }
    func exists(_ symbol:Branch.Position<Symbol>) -> Bool
    {
        self.metadata(local: symbol) != nil 
    }
    func exists(_ module:Branch.Position<Module>) -> Bool
    {
        self.metadata(local: module) != nil
    }
    func exists(_ diacritic:Branch.Diacritic) -> Bool
    {
        self.metadata(foreign: diacritic) != nil 
    }
    func exists(_ composite:Branch.Composite) -> Bool
    {
        guard let host:Branch.Position<Symbol> = composite.host 
        else 
        {
            return self.exists(composite.base)
        }
        if self.nationality == host.nationality
        {
            return self.metadata(local: host)?
                .contains(feature: composite) ?? false 
        }
        else 
        {
            return self.metadata(foreign: composite.diacritic)?
                .contains(feature: composite.base) ?? false
        }
    }
}
extension Package.Pinned 
{
    func resolve(_ link:_SymbolLink, scope:_Scope?, stems:Route.Stems, 
        where predicate:(Branch.Composite) throws -> Bool) 
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
        where predicate:(Branch.Composite) throws -> Bool) 
        rethrows -> _SymbolLink.Resolution?
    {
        if  let scope:_Scope, 
            let selection:_Selection<Branch.Composite> = try scope.scan(concatenating: link, 
                stems: stems, 
                until: { try self.routes.select($0, where: predicate) })
        {
            return .init(selection)
        }
        guard let namespace:Tree.Position<Module> = self.fasces.modules.find(.init(link.first))
        else 
        {
            return nil
        }
        guard let link:_SymbolLink = link.suffix
        else 
        {
            return .module(namespace.contemporary)
        }
        if  let key:Route.Key = stems[namespace.contemporary, link], 
            let selection:_Selection<Branch.Composite> = try self.routes.select(key, 
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

    func documentation(for symbol:Branch.Position<Symbol>) 
        -> DocumentationExtension<Branch.Position<Symbol>>
    {
        self.package.data.symbolDocumentation.value(of: symbol, 
            field: (\.documentation, \.documentation), 
            in: self.fasces.symbols) ?? .init()
    }
    func documentation(for article:Branch.Position<Article>) -> DocumentationExtension<Never>
    {
        self.package.data.standaloneDocumentation.value(of: article, 
            field: (\.documentation, \.documentation), 
            in: self.fasces.articles) ?? .init()
    }
    func documentation(for module:Branch.Position<Module>) -> DocumentationExtension<Never>
    {
        self.package.data.standaloneDocumentation.value(of: module, 
            field: (\.documentation, \.documentation), 
            in: self.fasces.modules) ?? .init()
    }
    
    func topLevelSymbols(of module:Branch.Position<Module>) -> Set<Branch.Position<Symbol>>
    {
        self.package.data.topLevelSymbols.value(of: module, 
            field: (\.topLevelSymbols, \.topLevelSymbols), 
            in: self.fasces.modules) ?? []
    }
    func topLevelArticles(of module:Branch.Position<Module>) -> Set<Branch.Position<Article>>
    {
        self.package.data.topLevelArticles.value(of: module, 
            field: (\.topLevelArticles, \.topLevelArticles), 
            in: self.fasces.modules) ?? []
    }

    func declaration(for symbol:Branch.Position<Symbol>) -> Declaration<Branch.Position<Symbol>>
    {
        self.package.data.declarations.value(of: symbol, 
            field: (\.declaration, \.declaration), 
            in: self.fasces.symbols) ?? .init(fallback: "<unavailable>")
    }
    
    @available(*, deprecated, renamed: "exists(_:)")
    func contains(_ composite:Branch.Composite) -> Bool 
    {
        self.exists(composite)
    }
}

extension Branch 
{
    enum NaturalDepth:Error 
    {
        case base 
    }
    enum CompositeDepth:Error 
    {
        case base 
        case host 
    }
}
extension Package.Pinned 
{
    func depth(of route:Route.Key, natural:Branch.Position<Symbol>) -> Branch.NaturalDepth?
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
                if $0.base != natural 
                {
                    throw Branch.NaturalDepth.base 
                }
            } as ()
            return nil  
        }
        catch 
        {
            return .base
        }
    }
    func depth(of route:Route.Key, host:Branch.Position<Symbol>, base:Branch.Position<Symbol>) 
        -> Branch.CompositeDepth?
    {
        do 
        {
            var depth:Branch.CompositeDepth? = nil
            try self.routes.select(route) 
            {
                guard self.exists($0)
                else 
                {
                    return () 
                }
                if $0.base != base 
                {
                    depth = .base 
                }
                else if case host? = $0.host
                {
                    return ()
                }
                else 
                {
                    throw Branch.CompositeDepth.host
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
//         let modules:Set<Branch.Position<Module>> = self._allModules()
//         for epoch:Epoch<Module> in self.fasces.modules 
//         {
//             for (module, divergence):(Branch.Position<Module>, Module.Divergence) in 
//                 epoch.divergences
//             {
//                 for (range, _):(Range<Symbol.Offset>, Branch.Position<Module>) in divergence.symbols 
//                 {
//                     for offset:Symbol.Offset in range 
//                     {
//                         self.missingSymbols.insert(.init(module, offset: offset))
//                     }
//                 }
//             }
//         }
//     }
//     func _allModules() -> Set<Branch.Position<Module>>
//     {
//         var modules:Set<Branch.Position<Module>> = []
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