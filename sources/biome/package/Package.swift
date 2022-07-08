import Resource
import Grammar

public 
struct Package:Identifiable, Sendable
{
    /// A globally-unique index referencing a package. 
    @usableFromInline 
    struct Index:Hashable, Comparable, Sendable 
    {
        let bits:UInt16
        
        @usableFromInline static 
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
    
    struct Heads 
    {
        @Keyframe<Article.Template<Ecosystem.Link>>.Head
        var template:Keyframe<Article.Template<Ecosystem.Link>>.Buffer.Index?
        
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
    @available(*, deprecated)
    var latest:Version
    {
        self.versions.latest 
    }
    private(set)
    var versions:Versions
    private(set) 
    var modules:CulturalBuffer<Module.Index, Module>, 
        symbols:CulturalBuffer<Symbol.Index, Symbol>,
        articles:CulturalBuffer<Article.Index, Article>
    private(set)
    var external:[Symbol.Diacritic: Keyframe<Symbol.Traits>.Buffer.Index]
    // per-module buffers
    private(set)
    var dependencies:Keyframe<Set<Module.Index>>.Buffer, // always populated 
        toplevels:Keyframe<Set<Symbol.Index>>.Buffer // always populated 
    // per-article buffers
    private(set)
    var headlines:Keyframe<Article.Headline>.Buffer
    // per-symbol buffers 
    private(set)
    var declarations:Keyframe<Symbol.Declaration>.Buffer, // always populated 
        facts:Keyframe<Symbol.Predicates>.Buffer // always populated
    // per-(external) host buffers 
    private(set)
    var opinions:Keyframe<Symbol.Traits>.Buffer
    // shared buffer. 
    private(set) 
    var templates:Keyframe<Article.Template<Ecosystem.Link>>.Buffer
    
    var groups:Symbol.Groups
    
    var name:String 
    {
        self.id.string
    }
    var kind:Kind 
    {
        self.id.kind
    }
    
    init(id:ID, index:Index)
    {
        self.id = id 
        self.index = index
        
        self.heads = .init()
        self.versions = .init()
        
        self.groups = .init()
        self.modules = .init()
        self.symbols = .init()
        self.articles = .init()
        self.external = [:]
        self.toplevels = .init()
        self.dependencies = .init()
        self.declarations = .init()
        
        self.facts = .init()
        self.opinions = .init()
        
        self.templates = .init()
        self.headlines = .init()
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
    
    func pinned() -> Pinned 
    {
        .init(self, at: self.versions.latest)
    }
    func pinned(_ pins:[Index: Version], exhibit:Version? = nil) -> Pinned 
    {
        .init(self, at: pins[self.index] ?? self.versions.latest, exhibit: exhibit)
    }
    
    var trunk:[String]
    {
        switch self.kind
        {
        case .swift, .core:         return []
        case .community(let name):  return [name]
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
    
    func allVersions(of composite:Symbol.Composite) -> [Version]
    {
        self.versions.indices.filter { self.contains(composite, at: $0) }
    }
    func allVersions(of article:Article.Index) -> [Version]
    {
        self.versions.indices.filter { self.contains(article, at: $0) }
    } 
    func allVersions(of module:Module.Index) -> [Version]
    {
        self.versions.indices.filter { self.contains(module, at: $0) }
    } 
    func allVersions() -> [Version]
    {
        .init(self.versions.indices)
    } 
    
    //  each ecosystem entity has a type of versioned node that stores 
    //  evolutionary information. 
    // 
    //  - modules: self.dependencies 
    //  - articles: self.templates 
    //  - local symbols: self.facts 
    //  - external symbols: self.opinions 
    mutating 
    func updateVersion(_ version:PreciseVersion, upstream:[Index: Version]) 
        -> Package.Pins<Version>
    {
        let pins:Package.Pins<Version> = self.versions.push(version, upstream: upstream)
        for module:Module in self.modules.all 
        {
            self.dependencies.push(pins.local, head: module.heads.dependencies)
        }
        for article:Article in self.articles.all 
        {
            self.templates.push(pins.local, head: article.heads.template)
        }
        for symbol:Symbol in self.symbols.all 
        {
            self.facts.push(pins.local, head: symbol.heads.facts)
        }
        for host:Keyframe<Symbol.Traits>.Buffer.Index in self.external.values 
        {
            self.opinions.push(pins.local, head: host)
        }
        return pins 
    }

    // we don’t use this quite the same as `contains(_:at:)` for ``Symbol.Composite``, 
    // because we still allow accessing module pages outside their availability ranges. 
    // 
    // we mainly use this to limit the results in the version menu dropdown.
    // FIXME: the complexity of this becomes quadratic-ish if we test *every* 
    // package version with this method.
    func contains(_ module:Module.Index, at version:Version) -> Bool 
    {
        if case (_, .extant)? = self.dependencies.at(version, 
            head: self[local: module].heads.dependencies)
        {
            return true 
        }
        else 
        {
            return false 
        }
    }
    func contains(_ article:Article.Index, at version:Version) -> Bool 
    {
        if case (_, .extant)? = self.templates.at(version, 
            head: self[local: article].heads.template)
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
        guard let host:Symbol.Index = composite.host
        else 
        {
            // natural symbol 
            if case (_, .extant)? = self.facts.at(version, 
                head: self.symbols[local: composite.base].heads.facts)
            {
                return true 
            }
            else 
            {
                return false 
            }
        }
        if let heads:Symbol.Heads = self[host]?.heads
        {
            // local host (primary or accepted culture)
            if case (let predicates, .extant)? = 
                    self.facts.at(version, head: heads.facts), 
                let traits:Symbol.Traits = composite.culture == host.module ? 
                    predicates.primary : predicates.accepted[composite.culture]
            {
                return traits.features.contains(composite.base)
            }
            else 
            {
                return false 
            }
        }
        // external host
        else if case (let traits, .extant)? = 
            self.opinions.at(version, head: self.external[composite.diacritic])
        {
            return traits.features.contains(composite.base)
        }
        else 
        {
            return false 
        }
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
    func updateDependencies(of cultures:[Module.Index], with dependencies:[Set<Module.Index>])
    {
        let current:Version = self.versions.latest
        for (index, dependencies):(Module.Index, Set<Module.Index>) in zip(cultures, dependencies)
        {
            self.dependencies.update(head: &self.modules[local: index].heads.dependencies, 
                to: current, with: dependencies)
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
        let current:Version = self.versions.latest
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
                to: current, with: toplevel)
        }
        return positions
    }
    private mutating 
    func updateDeclarations(_ declarations:[[Symbol.Index: Symbol.Declaration]]) 
    {
        let current:Version = self.versions.latest
        for (index, declaration):(Symbol.Index, Symbol.Declaration) in declarations.joined() 
        {
            self.declarations.update(head: &self.symbols[local: index].heads.declaration, 
                to: current, with: declaration)
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
        let current:Version = self.versions.latest
        for (index, facts):(Symbol.Index, Symbol.Facts) in facts
        {
            self.facts.update(head: &self.symbols[local: index].heads.facts, 
                to: current, with: facts.predicates)
        }
    }
    mutating 
    func updateOpinions(_ opinions:[Symbol.Diacritic: Symbol.Traits])
    {
        let current:Version = self.versions.latest
        for (diacritic, traits):(Symbol.Diacritic, Symbol.Traits) in opinions 
        {
            self.opinions.update(head: &self.external[diacritic], 
                to: current, with: traits)
        }
    }

    mutating 
    func updateDocumentation(_ compiled:Ecosystem.Documentation)
    {
        let current:Version = self.versions.latest
        for (index, template):(Ecosystem.Index, Article.Template<Ecosystem.Link>) in 
            compiled.templates 
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
                    to: current, with: template)
                
            case .article(let index): 
                self.templates.update(head: &self.articles[local: index].heads.template, 
                    to: current, with: template)
                
            case .module(let index): 
                self.templates.update(head: &self.modules[local: index].heads.template, 
                    to: current, with: template)
            case .package(self.index): 
                self.templates.update(head: &self.heads.template, 
                    to: current, with: template)
            
            case .package(_): 
                fatalError("unreachable")
            }
        }
        for (index, headline):(Article.Index, Article.Headline) in 
            compiled.headlines
        {
            self.headlines.update(head: &self.articles[local: index].heads.headline, 
                to: current, with: headline)
        }
    }
    mutating 
    func spreadDocumentation(_ migrants:[Symbol.Index: Article.Template<Ecosystem.Link>]) 
    {
        let current:Version = self.versions.latest
        for (migrant, template):(Symbol.Index, Article.Template<Ecosystem.Link>) in migrants 
        {
            self.templates.update(head: &self.symbols[local: migrant].heads.template, 
                to: current, with: template)
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
    func addExtensions(in cultures:[Module.Index], graphs:[Module.Graph], stems:inout Stems) 
        -> (articles:[[Article.Index: Extension]], extensions:[[String: Extension]])
    {
        var articles:[[Article.Index: Extension]] = []
            articles.reserveCapacity(graphs.count)
        var extensions:[[String: Extension]] = []
            extensions.reserveCapacity(graphs.count)
        for (culture, graph):(Module.Index, Module.Graph) in zip(cultures, graphs)
        {
            let column:(articles:[Article.Index: Extension], extensions:[String: Extension]) =
                self.addExtensions(in: culture, graph: graph, stems: &stems)
            extensions.append(column.extensions)
            articles.append(column.articles)
        }
        return (articles, extensions)
    }
    private mutating 
    func addExtensions(in culture:Module.Index, graph:Module.Graph, stems:inout Stems) 
        -> (articles:[Article.Index: Extension], extensions:[String: Extension])
    {
        var articles:[Article.Index: Extension] = [:]
        var extensions:[String: Extension] = [:] 
        
        let start:Int = self.articles.count
        for article:Extension in graph.articles
        {
            if let binding:String = article.binding 
            {
                extensions[binding] = article 
                continue 
            }
            // article namespace is always its culture. 
            guard let path:Path = article.metadata.path
            else 
            {
                // should have been checked earlier
                fatalError("unreachable")
            }
            let route:Route = .init(culture, 
                      stems.register(components: path.prefix), 
                .init(stems.register(component:  path.last), 
                orientation: .straight))
            let index:Article.Index = 
                self.articles.insert(.init(route), culture: culture)
            {
                (id:Article.ID, _:Article.Index) in .init(id: id, path: path)
            }
            articles[index] = article
        }
        let end:Int = self.articles.count 
        if start < end
        {
            self.modules[local: culture].articles.append(start ..< end)
        }
        return (articles, extensions)
    }
    
    mutating 
    func addSymbols(through scopes:[Symbol.Scope], graphs:[Module.Graph], stems:inout Stems) 
        -> [[Symbol.Index: Vertex.Frame]]
    {
        let extant:Int = self.symbols.count
        
        let symbols:[[Symbol.Index: Vertex.Frame]] = zip(scopes, graphs).map
        {
            self.addSymbols(through: $0.0, graph: $0.1, stems: &stems)
        }
        
        let updated:Int = symbols.reduce(0) { $0 + $1.count }
        print("(\(self.id)) updated \(updated) symbols (\(self.symbols.count - extant) are new)")
        return symbols
    }
    private mutating 
    func addSymbols(through scope:Symbol.Scope, graph:Module.Graph, stems:inout Stems) 
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
            
            let start:Int = self.symbols.count
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
                              stems.register(components: vertex.path.prefix), 
                        .init(stems.register(component:  vertex.path.last), 
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
                            route.leaf.stem : stems.register(components: vertex.path))
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
            let end:Int = self.symbols.count 
            if start < end
            {
                self.modules[local: scope.culture].symbols.append(Symbol.ColonialRange.init(
                    namespace: namespace, offsets: start ..< end))
            }
        }
        return updates
    }
}
