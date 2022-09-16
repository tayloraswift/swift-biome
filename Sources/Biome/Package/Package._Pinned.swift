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
    // this isn’t *quite* ``SurfaceBuilder.Context``, because ``local`` is pinned here.
    struct Context:Sendable 
    {
        let upstream:[Index: _Pinned]
        let local:_Pinned 

        init(local:_Pinned, context:__shared Packages)
        {
            self.init(local: local, pins: local.package.tree[local.version].pins, 
                context: context)
        }
        init(local:_Pinned, pins:__shared [Index: _Version], context:__shared Packages)
        {
            self.local = local 
            var upstream:[Index: _Pinned] = .init(minimumCapacity: pins.count)
            for (index, version):(Index, _Version) in pins 
            {
                upstream[index] = .init(context[index], version: version)
            }
            self.upstream = upstream
        }
        subscript(package:Index) -> _Pinned?
        {
            _read 
            {
                yield self.local.package.index == package ? self.local : self.upstream[package]
            }
        }
    }
}

struct Address 
{
    var function:Service.Function 
    var global:GlobalAddress
}
struct GlobalAddress 
{
    var residency:Package.ID?
    var tag:Tag?
    var local:LocalAddress?
}
struct LocalAddress 
{
    var namespace:Module.ID 
    var symbol:SymbolAddress?
}
struct SymbolAddress 
{
    var orientation:_SymbolLink.Orientation 
    var path:Path 
    var host:Symbol.ID? 
    var base:Symbol.ID?
    var nationality:_SymbolLink.Nationality?
}
extension Package.Context 
{
    func address(of composite:Branch.Composite) 
    {
        
    }

    func find(symbol:Branch.Position<Symbol>) -> Symbol?
    {
        if  let pinned:Package._Pinned = self[symbol.package], 
            let position:Tree.Position<Symbol> = 
                symbol.pluralized(bisecting: pinned.symbols)
        {
            return pinned.package.tree[local: position]
        }
        else 
        {
            return nil
        }
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

    @available(*, deprecated, renamed: "documentation(for:)")
    func documentation(_ symbol:Branch.Position<Symbol>) 
        -> DocumentationExtension<Branch.Position<Symbol>>
    {
        self.documentation(for: symbol)
    }
    @available(*, deprecated, renamed: "documentation(for:)")
    func documentation(_ article:Branch.Position<Article>) -> DocumentationExtension<Never>
    {
        self.documentation(for: article)
    }
    @available(*, deprecated, renamed: "documentation(for:)")
    func documentation(_ module:Branch.Position<Module>) -> DocumentationExtension<Never>
    {
        self.documentation(for: module)
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

    @available(*, deprecated, renamed: "topLevelSymbols(of:)")
    func toplevel(_ module:Module.Index) -> Set<Symbol.Index>
    {
        self.topLevelSymbols(of: module)
    }
    @available(*, deprecated, renamed: "topLevelArticles(of:)")
    func guides(_ module:Module.Index) -> Set<Article.Index>
    {
        self.topLevelArticles(of: module)
    }
    
    @available(*, deprecated, renamed: "declaration(for:)")
    func declaration(_ symbol:Symbol.Index) -> Declaration<Symbol.Index>
    {
        self.declaration(for: symbol)
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
    enum CompositeDepth:Error 
    {
        case base 
        case host 
    }
}
extension Package._Pinned 
{
    func depth(of composite:Branch.Composite, route:Route.Key) -> Branch.CompositeDepth?
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
                if $0.base != composite.base 
                {
                    depth = .base 
                }
                else if let host:Branch.Position<Symbol> = composite.host, 
                        let overload:Branch.Position<Symbol> = $0.host, 
                            overload != host 
                {
                    throw Branch.CompositeDepth.host
                }
            } as ()
            return depth 
        }
        catch let depth as Branch.CompositeDepth 
        {
            return depth
        }
        catch 
        {
            fatalError("unreachable")
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