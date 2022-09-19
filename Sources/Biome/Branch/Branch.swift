import PackageResolution

enum _Dependency:Sendable 
{
    case available(Version)
    case unavailable(Tag, String)
}
enum _DependencyError:Error 
{
    case package                                (unavailable:Package.ID)
    case pin                                    (unavailable:Package.ID)
    case version                 (unavailable:(Tag, String), Package.ID)
    case module (unavailable:Module.ID, (Branch.ID, String), Package.ID)
    case target (unavailable:Module.ID,  Branch.ID)
}

public 
struct Branch:Identifiable, Sendable 
{
    public 
    let id:Tag
    let index:Version.Branch

    let fork:Version?
    var revisions:Revisions

    var foreign:[Diacritic: Symbol.ForeignDivergence]
    var articles:Buffer<Article>, 
        symbols:Buffer<Symbol>,
        modules:Buffer<Module>
    var routes:[Route: Stack]

    var _surface:Surface 

    init(id:ID, index:Version.Branch, fork:(version:Version, ring:Ring)?)
    {
        self.id = id 
        self.index = index 

        self.fork = fork?.version

        self.revisions = .init()
        
        self.foreign = [:]
        self.articles = .init(startIndex: fork?.ring.articles ?? 0)
        self.symbols = .init(startIndex: fork?.ring.symbols ?? 0)
        self.modules = .init(startIndex: fork?.ring.modules ?? 0)
        self.routes = [:]

        self._surface = .init()
    }

    var head:Version.Revision? 
    {
        self.revisions.indices.last
    }
    
    subscript(range:PartialRangeThrough<Version.Revision>) -> Fascis
    {
        let ring:Ring = self.revisions[range.upperBound].ring
        return .init(
            articles: self.articles[..<ring.articles],
            symbols: self.symbols[..<ring.symbols], 
            modules: self.modules[..<ring.modules], 
            foreign: self.foreign, 
            routes: self.routes, 
            branch: self.index,
            limit: range.upperBound, 
            fork: self.fork)
    }
}
extension Branch 
{
    mutating 
    func commit(hash:String, pins:[Package.Index: Version], date:Date, tag:Tag?) -> Version
    {
        let commit:Version.Revision = self.revisions.endIndex
        self.revisions.append(.init(hash: hash, 
            ring: .init(
                modules: self.modules.endIndex, 
                symbols: self.symbols.endIndex, 
                articles: self.articles.endIndex), 
            pins: pins, 
            date: date, 
            tag: tag))
        return .init(self.index, commit)
    }
}
extension Branch 
{
    mutating 
    func add(module id:Module.ID, culture:Package.Index, fasces:Fasces) 
        -> PluralPosition<Module>
    {
        if let existing:PluralPosition<Module> = fasces.modules.find(id)
        {
            return existing 
        }
        let position:Atom<Module> = self.modules.insert(id, culture: culture, 
            Module.init(id:index:))
        return position.pluralized(self.index)
    }
    mutating 
    func add(graph:SymbolGraph, namespaces:__owned Namespaces, 
        upstream:[Package.Index: Package._Pinned],
        fasces:Fasces, 
        stems:inout Route.Stems) 
        -> ModuleInterface
    {
        let (articles, _extensions):(ModuleInterface.Abstractor<Article>, [Extension]) = self.addExtensions(from: graph, 
            namespace: namespaces.module, 
            trunk: fasces.articles, 
            stems: &stems)
        var symbols:ModuleInterface.Abstractor<Symbol> = self.addSymbols(from: graph, 
            namespaces: namespaces, 
            upstream: upstream, 
            trunk: fasces.symbols, 
            stems: &stems)
        
        assert(symbols.count == graph.vertices.count)

        symbols.extend(over: graph.identifiers, by: fasces.symbols.find(_:))

        return .init(namespaces: _move namespaces, 
            _extensions: _move _extensions,
            articles: _move articles,
            symbols: _move symbols)
    }

    private mutating 
    func addSymbols(from graph:SymbolGraph, namespaces:Namespaces, 
        upstream:[Package.Index: Package._Pinned], 
        trunk:Fasces.SymbolView, 
        stems:inout Route.Stems) 
        -> ModuleInterface.Abstractor<Symbol>
    {
        let linked:Set<Atom<Module>> = namespaces.import()

        var positions:[PluralPosition<Symbol>?] = []
            positions.reserveCapacity(graph.identifiers.count)
        for (namespace, vertices):(Module.ID, ArraySlice<SymbolGraph.Vertex<Int>>) in 
            graph.colonies
        {
            // will always succeed for the core subgraph
            guard let namespace:Atom<Module> = namespaces.linked[namespace]?.contemporary
            else 
            {
                print("warning: ignored colonial symbolgraph '\(graph.id)@\(namespace)'")
                print("note: '\(namespace)' is not a known dependency of '\(graph.id)'")

                positions.append(contentsOf: repeatElement(nil, count: vertices.count))
                continue 
            }
            
            let start:Symbol.Offset = self.symbols.endIndex
            for (offset, vertex):(Int, SymbolGraph.Vertex<Int>) in 
                zip(vertices.indices, vertices)
            {
                positions.append(self.addSymbol(graph.identifiers[offset], 
                    culture: namespaces.culture, 
                    namespace: namespace, 
                    linked: linked, 
                    vertex: vertex, 
                    upstream: upstream, 
                    trunk: trunk, 
                    stems: &stems))
            }
            let end:Symbol.Offset = self.symbols.endIndex 
            if start < end
            {
                if self.index == namespaces.module.position.branch 
                {
                    self.modules[contemporary: namespaces.culture].symbols
                        .append((start ..< end, namespace))
                }
                else 
                {
                    self.modules.divergences[namespaces.culture, default: .init()].symbols
                        .append((start ..< end, namespace))
                }
            }
        }
        return .init(_move positions)
    }
    private mutating 
    func addSymbol(_ id:Symbol.ID, culture:Atom<Module>, namespace:Atom<Module>, 
        linked:Set<Atom<Module>>,
        vertex:SymbolGraph.Vertex<Int>,
        upstream:[Package.Index: Package._Pinned], 
        trunk:Fasces.SymbolView, 
        stems:inout Route.Stems)
        -> PluralPosition<Symbol>
    {
        if let existing:PluralPosition<Symbol> = trunk.find(id)
        {
            // swift encodes module names in symbol identifiers, so if a symbol changes culture, 
            // something really weird has happened.
            if existing.contemporary.culture == culture 
            {
                return existing 
            }
            else 
            {
                fatalError("symbol with id '\(id)' has already been registered in a different module! symbolgraph may have been corrupted!")
            }
        } 
        for upstream:Package._Pinned in upstream.values 
        {
            if  let restated:PluralPosition<Symbol> = upstream.symbols.find(id), 
                    linked.contains(restated.contemporary.culture)
            {
                return restated 
            }
        }
        let position:Atom<Symbol> = self.symbols.insert(id, culture: culture)
        {
            (id:Symbol.ID, _:Atom<Symbol>) in 
            let route:Route = .init(namespace, 
                      stems.register(components: vertex.path.prefix), 
                .init(stems.register(component:  vertex.path.last), 
                orientation: vertex.community.orientation))
            // if the symbol could inherit features, generate a stem 
            // for its children from its full path. this stem will only 
            // go to waste if a concretetype is completely uninhabited, 
            // which is very rare.
            let kind:Symbol.Kind 
            switch vertex.community
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
        return position.pluralized(self.index)
    }

    // TODO: ideally we want to be rendering markdown AOT. so once that is implemented 
    // in the `SymbolGraphs` module, we can get rid of the ugly tuple return here.
    private mutating 
    func addExtensions(from graph:SymbolGraph, namespace:Namespace, trunk:Fasces.ArticleView, 
        stems:inout Route.Stems) 
        -> (ModuleInterface.Abstractor<Article>, [Extension])
    {
        let _extensions:[Extension] = graph.extensions.map
        {
            .init(markdown: $0.source, name: $0.name)
        }

        var positions:[PluralPosition<Article>?] = []
            positions.reserveCapacity(graph.extensions.count)
        let start:Article.Offset = self.articles.endIndex
        for article:Extension in _extensions
        {
            switch (article.metadata.path, article.binding)
            {
            case    (.explicit(let path)?, _), 
                    (.implicit(let path)?, nil):
                // articles are always associated with modules, and the name
                // of that module is part of the article identity.
                positions.append(self.addArticle(path, 
                    culture: namespace.culture, 
                    trunk: trunk, 
                    stems: &stems))
            
            case    (.implicit(_)?, _?), (nil, _): 
                positions.append(nil)
            }
        }
        let end:Article.Offset = self.articles.endIndex
        if start < end
        {
            if self.index == namespace.position.branch 
            {
                self.modules[contemporary: namespace.culture].articles
                    .append(start ..< end)
            }
            else 
            {
                self.modules.divergences[namespace.culture, default: .init()].articles
                    .append(start ..< end)
            }
        }
        return (.init(_move positions), _extensions)
    }
    private mutating 
    func addArticle(_ path:Path, culture:Atom<Module>, trunk:Fasces.ArticleView, 
        stems:inout Route.Stems)
        -> PluralPosition<Article>
    {
        // article namespace is always its culture. 
        let stem:Route.Stem = stems.register(components: path.prefix) 
        let leaf:Route.Stem = stems.register(component: path.last)

        let id:Article.ID = .init(culture, stem, leaf)

        if let existing:PluralPosition<Article> = trunk.find(id)
        {
            guard existing.contemporary.culture == culture 
            else 
            {
                fatalError("unreachable")
            }
            return existing 
        }
        let position:Atom<Article> = self.articles.insert(id, culture: culture)
        {
            (id:Article.ID, _:Atom<Article>) in 
            .init(id: id, path: path)
        }
        return position.pluralized(self.index)
    }
}
