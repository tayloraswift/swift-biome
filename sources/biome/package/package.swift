import Resource
import Grammar

public 
struct Package:Identifiable, Sendable
{
    enum UpdateError:Error 
    {
        case versionNotIncremented(Version, from:Version)
    }
    /// A globally-unique index referencing a package. 
    struct Index:Hashable, Comparable, Sendable 
    {
        let bits:UInt16
        
        static 
        func < (lhs:Self, rhs:Self) -> Bool 
        {
            lhs.bits < rhs.bits
        }
        
        var offset:Int 
        {
            .init(self.bits)
        }
        init(offset:Int)
        {
            self.bits = .init(offset)
        }
    }
    
    public 
    enum Kind:Hashable, Comparable, Sendable 
    {
        case swift 
        case core
        case community(String)
    }
    
    struct Pin:Hashable, Sendable 
    {
        var culture:Index 
        var version:Version
    }
    struct Pins:Equatable, Sendable 
    {
        let version:Version
        let upstream:[Index: Version]
        
        init(version:Version, upstream:[Index: Version])
        {
            self.version = version
            self.upstream = upstream
        }
        
        func isotropic(culture:Index) -> [Index: Version]
        {
            var isotropic:[Index: Version] = self.upstream 
            isotropic[culture] = self.version 
            return isotropic
        }
    }
    
    struct Heads 
    {
        @Keyframe<Article.Template<Link>>.Head
        var template:Keyframe<Article.Template<Link>>.Buffer.Index?
        
        init() 
        {
            self._template = .init()
        }
    }
    
    public 
    let id:ID
    let index:Index
    
    private(set)
    var heads:Heads
    // private 
    // var tag:Resource.Tag?
    var latest:Version
    private(set) 
    var modules:CulturalBuffer<Module.Index, Module>, 
        symbols:CulturalBuffer<Symbol.Index, Symbol>,
        articles:CulturalBuffer<Article.Index, Article>
    private(set)
    var external:[Symbol.Diacritic: Keyframe<Symbol.Traits>.Buffer.Index]
    private(set)
    var versions:[Version: Pins], 
        toplevels:Keyframe<Set<Symbol.Index>>.Buffer, // always populated 
        dependencies:Keyframe<Set<Module.Index>>.Buffer, // always populated 
        declarations:Keyframe<Symbol.Declaration>.Buffer // always populated 
    private(set)
    var facts:Keyframe<Symbol.Predicates>.Buffer, // always populated
        opinions:Keyframe<Symbol.Traits>.Buffer
    private(set)
    var templates:Keyframe<Article.Template<Link>>.Buffer
    
    var groups:Symbol.Groups
    
    var name:String 
    {
        self.id.string
    }
    var kind:Kind 
    {
        self.id.kind
    }
    
    init(id:ID, index:Index, version:Version)
    {
        self.id = id 
        self.index = index
        
        self.heads = .init()
        
        // self.tag = "2.0.0"
        self.latest = version
        self.groups = .init()
        self.modules = .init()
        self.symbols = .init()
        self.articles = .init()
        self.external = [:]
        self.versions = [:]
        self.toplevels = .init()
        self.dependencies = .init()
        self.declarations = .init()
        
        self.facts = .init()
        self.opinions = .init()
        
        self.templates = .init()
    }

    subscript(local module:Module.Index) -> Module 
    {
        _read 
        {
            yield self.modules[local: module]
        }
    }
    subscript(local symbol:Symbol.Index) -> Symbol
    {
        _read 
        {
            yield self.symbols[local: symbol]
        }
    } 
    subscript(local article:Article.Index) -> Article
    {
        _read 
        {
            yield self.articles[local: article]
        }
    } 
    
    subscript(module:Module.Index) -> Module?
    {
        self.index ==        module.package ? self[local: module] : nil
    }
    subscript(symbol:Symbol.Index) -> Symbol?
    {
        self.index == symbol.module.package ? self[local: symbol] : nil
    }
    subscript(article:Article.Index) -> Article?
    {
        self.index == article.module.package ? self[local: article] : nil
    }
    
    func pinned(_ pins:[Index: Version]) -> Pinned 
    {
        .init(self, at: pins[self.index] ?? self.latest)
    }
    
    var root:Link.Reference<[String]> 
    {
        switch self.kind
        {
        case .swift: 
            return .init(path: []) 
        case .core, .community(_):
            return .init(path: [self.name])
        }
    }
    
    func abbreviate(_ version:Version) -> Version?
    {
        guard version.isSemantic 
        else 
        {
            return version 
        }
        if      case version? = self.versions[.latest]?.version
        {
            return nil 
        }
        else if case version? = self.versions[version.minorless]?.version 
        {
            return version.minorless 
        }
        else if case version? = self.versions[version.patchless]?.version 
        {
            return version.patchless
        }
        else if case version? = self.versions[version.editionless]?.version 
        {
            return version.editionless 
        }
        else
        {
            return version
        }
    }
    
    func depth(of composite:Symbol.Composite, at version:Version, route:Route)
        -> (host:Bool, base:Bool)
    {
        var explicit:(host:Bool, base:Bool) = (false, false)
        switch self.groups[route]
        {
        case .none: 
            assert(false)
            
        case .one(let occupant):
            assert(occupant == composite)
        
        case .many(let occupants):
            filtering:
            for (base, diacritics):(Symbol.Index, Symbol.Subgroup) in occupants
            {
                switch (base == composite.base, diacritics)
                {
                case (_, .none):
                    assert(false)
                
                case (true, .one(let diacritic)):
                    assert(diacritic == composite.diacritic)
                
                case (false, .one(let diacritic)):
                    if self.contains(.init(base, diacritic), at: version)
                    {
                        explicit.base = true 
                    }
                    
                case (true, .many(let diacritics)):
                    for diacritic:Symbol.Diacritic in diacritics 
                        where diacritic != composite.diacritic 
                    {
                        if self.contains(.init(base, diacritic), at: version)
                        {
                            explicit.base = true 
                            explicit.host = true 
                            break filtering
                        }
                    }
                
                case (false, .many(let diacritics)):
                    for diacritic:Symbol.Diacritic in diacritics 
                    {
                        if self.contains(.init(base, diacritic), at: version)
                        {
                            explicit.base = true 
                            continue filtering
                        }
                    }
                }
            }
        }
        return explicit
    }
    
    func availableVersions(_ composite:Symbol.Composite) -> Set<Version> 
    {
        self.availableVersions { self.contains(composite, at: $0) }
    }
    func availableVersions(_ module:Module.Index) -> Set<Version> 
    {
        self.availableVersions { self.contains(module, at: $0) }
    }
    func availableVersions() -> Set<Version> 
    {
        .init(self.versions.values.lazy.map(\.version))
    }
    private 
    func availableVersions(where predicate:(Version) throws -> Bool) 
        rethrows -> Set<Version> 
    {
        var versions:Set<Version> = []
        // ``Set.contains(_:)`` check helps avoid extra 
        // ``Package.contains(_:at:)`` queries
        for pins:Pins in self.versions.values 
            where try !versions.contains(pins.version) && predicate(pins.version)
        {
            versions.insert(pins.version)
        }
        return versions
    }
    // we don’t use this quite the same as `contains(_:at:)` for ``Symbol.Composite``, 
    // because we still allow accessing module pages outside their availability ranges. 
    // 
    // we mainly use this to limit the results in the version menu dropdown.
    // FIXME: the complexity of this becomes quadratic-ish if we test *every* 
    // package version with this method.
    func contains(_ module:Module.Index, at version:Version) -> Bool 
    {
        if case _? = self.dependencies.at(version, 
            head: self[local: module].heads.dependencies)
        {
            return true 
        }
        else 
        {
            return false 
        }
    }
    // FIXME: the complexity of this becomes quadratic-ish if we test *every* 
    // package version with this method, which we do for the version menu dropdowns
    func contains(_ composite:Symbol.Composite, at version:Version) -> Bool 
    {
        if let host:Symbol.Index = composite.host
        {
            if let heads:Symbol.Heads = self[host]?.heads
            {
                if  let predicates:Symbol.Predicates = self.facts.at(version, 
                        head: heads.facts), 
                    let traits:Symbol.Traits = composite.culture == host.module ? 
                        predicates.primary : predicates.accepted[composite.culture]
                {
                    return traits.features.contains(composite.base)
                }
            }
            //  external host
            else if let traits:Symbol.Traits = 
                self.opinions.at(version, head: self.external[composite.diacritic])
            {
                return traits.features.contains(composite.base)
            }
        }
        else if case _? = self.facts.at(version, 
            head: self.symbols[local: composite.base].heads.facts)
        {
            return true 
        }
        
        return false 
    }
    
    mutating 
    func pollinate(local symbol:Symbol.Index, from pin:Module.Pin)
    {
        self.symbols[local: symbol].pollen.insert(pin)
    }
    
    func currentOpinion(_ diacritic:Symbol.Diacritic) -> Symbol.Traits?
    {
        self.external[diacritic].map { self.opinions[$0].value }
    }
}

extension Package 
{
    mutating 
    func updatePins(_ pins:Pins)
    {
        self.versions[self.latest] = pins
        
        if  self.latest.isSemantic 
        {
            self.versions[self.latest.editionless] = pins
            self.versions[self.latest.patchless] = pins
            self.versions[self.latest.minorless] = pins
            self.versions[.latest] = pins
        }
    }

    mutating 
    func updateDependencies(of cultures:[Module.Index], with dependencies:[Set<Module.Index>])
    {
        for (index, dependencies):(Module.Index, Set<Module.Index>) in zip(cultures, dependencies)
        {
            self.dependencies.update(head: &self.modules[local: index].heads.dependencies, 
                to: self.latest, with: dependencies)
        }
    }
    
    mutating 
    func updateDeclarations(scopes:[Symbol.Scope], symbols:[[Symbol.Index: Vertex.Frame]]) 
        throws -> [Dictionary<Symbol.Index, Symbol.Declaration>.Keys]
    {
        let declarations:[[Symbol.Index: Symbol.Declaration]] = try zip(scopes, symbols).map
        {
            let (scope, symbols):(Symbol.Scope, [Symbol.Index: Vertex.Frame]) = $0
            return try symbols.mapValues { try .init($0, scope: scope) }
        }
        self.updateDeclarations(declarations)
        
        let positions:[Dictionary<Symbol.Index, Symbol.Declaration>.Keys] = 
            declarations.map(\.keys)
        // also update module toplevels 
        for (scope, symbols):(Symbol.Scope, Dictionary<Symbol.Index, Symbol.Declaration>.Keys) 
            in zip(scopes, positions)
        {
            var toplevel:Set<Symbol.Index> = [] 
            for symbol:Symbol.Index in symbols where self[local: symbol].path.prefix.isEmpty
            {
                // a symbol is toplevel if it has a single path component. this 
                // is not the same thing as having a `nil` shape.
                toplevel.insert(symbol)
            }
            self.toplevels.update(head: &self.modules[local: scope.culture].heads.toplevel, 
                to: self.latest, with: toplevel)
        }
        return positions
    }
    private mutating 
    func updateDeclarations(_ declarations:[[Symbol.Index: Symbol.Declaration]]) 
    {
        for (index, declaration):(Symbol.Index, Symbol.Declaration) in declarations.joined() 
        {
            self.declarations.update(head: &self.symbols[local: index].heads.declaration, 
                to: self.latest, with: declaration)
        }
    }
    
    mutating 
    func assignShapes(_ facts:[Symbol.Index: Symbol.Facts])
    {
        for (index, facts):(Symbol.Index, Symbol.Facts) in facts
        {
            self.symbols[local: index].shape = facts.shape
        }
    }
    
    mutating 
    func updateFacts(_ facts:[Symbol.Index: Symbol.Facts])
    {
        for (index, facts):(Symbol.Index, Symbol.Facts) in facts
        {
            self.facts.update(head: &self.symbols[local: index].heads.facts, 
                to: self.latest, 
                with: facts.predicates)
        }
    }
    mutating 
    func updateOpinions(_ opinions:[Symbol.Diacritic: Symbol.Traits])
    {
        for (diacritic, traits):(Symbol.Diacritic, Symbol.Traits) in opinions 
        {
            self.opinions.update(head: &self.external[diacritic], 
                to: self.latest, 
                with: traits)
        }
    }

    mutating 
    func updateDocumentation(_ compiled:[Ecosystem.Index: Article.Template<Link>])
    {
        for (index, template):(Ecosystem.Index, Article.Template<Link>) in compiled 
        {
            switch index 
            {
            case .composite(let composite):
                guard case nil = composite.host 
                else 
                {
                    fatalError("unimplemented")
                }
                self.templates.update(head: &self.symbols[local: composite.base].heads.template, 
                    to: self.latest, with: template)
                
            case .article(let index): 
                self.templates.update(head: &self.articles[local: index].heads.template, 
                    to: self.latest, with: template)
                
            case .module(let index): 
                self.templates.update(head: &self.modules[local: index].heads.template, 
                    to: self.latest, with: template)
            case .package(self.index): 
                self.templates.update(head: &self.heads.template, 
                    to: self.latest, with: template)
            
            case .package(_): 
                fatalError("unreachable")
            }
        }
    }
    mutating 
    func spreadDocumentation(_ migrants:[Symbol.Index: Article.Template<Link>]) 
    {
        for (migrant, template):(Symbol.Index, Article.Template<Link>) in migrants 
        {
            self.templates.update(head: &self.symbols[local: migrant].heads.template, 
                to: self.latest, with: template)
        }
    }
}

extension Package 
{
    mutating 
    func addModules(_ graphs:[Module.Graph]) -> [Module.Index]
    {
        graphs.map 
        { 
            self.modules.insert($0.core.namespace, culture: self.index, Module.init(id:index:))
        }
    }
    
    mutating 
    func addExtensions(in cultures:[Module.Index], graphs:[Module.Graph], keys:inout Route.Keys) 
        -> (articles:[[Article.Index: Extension]], extensions:[[String: Extension]])
    {
        var articles:[[Article.Index: Extension]] = []
            articles.reserveCapacity(graphs.count)
        var extensions:[[String: Extension]] = []
            extensions.reserveCapacity(graphs.count)
        for (culture, graph):(Module.Index, Module.Graph) in zip(cultures, graphs)
        {
            let column:(articles:[Article.Index: Extension], extensions:[String: Extension]) =
                self.addExtensions(in: culture, graph: graph, keys: &keys)
            extensions.append(column.extensions)
            articles.append(column.articles)
        }
        return (articles, extensions)
    }
    private mutating 
    func addExtensions(in culture:Module.Index, graph:Module.Graph, keys:inout Route.Keys) 
        -> (articles:[Article.Index: Extension], extensions:[String: Extension])
    {
        var articles:[Article.Index: Extension] = [:]
        var extensions:[String: Extension] = [:] 
        for article:Extension in graph.articles
        {
            if let binding:String = article.binding 
            {
                extensions[binding] = article 
                continue 
            }
            // article namespace is always its culture
            guard let path:Path = article.metadata.path
            else 
            {
                // should have been checked earlier
                fatalError("unreachable")
            }
            let id:Route = .init(culture, 
                      keys.register(components: path.prefix), 
                .init(keys.register(component:  path.last), 
                orientation: .straight))
            let index:Article.Index = self.articles.insert(id, culture: culture)
            {
                (route:Route, _:Article.Index) in 
                .init(path: path, route: route)
            }
            articles[index] = article
        }
        return (articles, extensions)
    }
    
    mutating 
    func addSymbols(through scopes:[Symbol.Scope], graphs:[Module.Graph], keys:inout Route.Keys) 
        -> [[Symbol.Index: Vertex.Frame]]
    {
        let extant:Int = self.symbols.count
        
        let symbols:[[Symbol.Index: Vertex.Frame]] = zip(scopes, graphs).map
        {
            self.addSymbols(through: $0.0, graph: $0.1, keys: &keys)
        }
        
        let updated:Int = symbols.reduce(0) { $0 + $1.count }
        print("(\(self.id)) updated \(updated) symbols (\(self.symbols.count - extant) are new)")
        return symbols
    }
    private mutating 
    func addSymbols(through scope:Symbol.Scope, graph:Module.Graph, keys:inout Route.Keys) 
        -> [Symbol.Index: Vertex.Frame]
    {            
        var updates:[Symbol.Index: Vertex.Frame] = [:]
        for colony:Module.Subgraph in [[graph.core], graph.colonies].joined()
        {
            // will always succeed for the core subgraph
            guard let namespace:Module.Index = scope.namespaces[colony.namespace]
            else 
            {
                print("warning: ignored colonial symbolgraph '\(graph.core.namespace)@\(colony.namespace)'")
                print("note: '\(colony.namespace)' is not a known dependency of '\(graph.core.namespace)'")
                continue 
            }
            
            let offset:Int = self.symbols.count
            for (id, vertex):(Symbol.ID, Vertex) in colony.vertices 
            {
                if scope.contains(id) 
                {
                    // usually happens because of inferred symbols. ignore.
                    continue 
                }
                let index:Symbol.Index = self.symbols.insert(id, culture: scope.culture)
                {
                    (id:Symbol.ID, _:Symbol.Index) in 
                    let route:Route = .init(namespace, 
                              keys.register(components: vertex.path.prefix), 
                        .init(keys.register(component:  vertex.path.last), 
                        orientation: vertex.color.orientation))
                    // if the symbol could inherit features, generate a stem 
                    // for its children from its full path. this stem will only 
                    // go to waste if a concretetype is completely uninhabited, 
                    // which is very rare.
                    let kind:Symbol.Kind 
                    switch vertex.color 
                    {
                    case .associatedtype: 
                        kind = .associatedtype 
                    case .concretetype(let concrete): 
                        kind = .concretetype(concrete, path: vertex.path.prefix.isEmpty ? 
                            route.leaf.stem : keys.register(components: vertex.path))
                    case .callable(let callable): 
                        kind = .callable(callable)
                    case .global(let global): 
                        kind = .global(global)
                    case .protocol: 
                        kind = .protocol 
                    case .typealias: 
                        kind = .typealias
                    }
                    return .init(id: id, path: vertex.path, kind: kind, route: route)
                }
                
                updates[index] = vertex.frame
            }
            
            self.modules[local: scope.culture].matrix.append(Symbol.ColonialRange.init(
                namespace: namespace, offsets: offset ..< self.symbols.count))
        }
        return updates
    }
}
