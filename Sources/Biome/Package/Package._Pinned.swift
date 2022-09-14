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
        self[pinned.package.index] = pinned
    }
}

extension Package 
{
    struct _Pinned:Sendable 
    {
        let package:Package 
        let version:_Version
        private 
        let fasces:Fasces 

        @available(*, deprecated)
        var _fasces:Fasces 
        {
            self.fasces
        }
        
        init(_ package:Package, version:_Version)
        {
            self.package = package
            self.version = version
            self.fasces = self.package.tree.fasces(through: self.version)
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

extension Package._Pinned 
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
        if self.package.index == host.package
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
    
    func resolve(_ link:_SymbolLink, scope:_Scope?, stems:Route.Stems) 
        -> _SymbolLink.Resolution?
    {
        self.resolve(link, scope: scope, stems: stems, where: self.exists(_:))
    }
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