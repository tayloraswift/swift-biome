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
    var latest:Version? 
    {
        self.head.map { .init(self.index, $0) }
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
    func commit(token:UInt, hash:String, pins:[Packages.Index: Version], date:Date, tag:Tag?) 
        -> Version
    {
        let commit:Version.Revision = self.revisions.endIndex
        self.revisions.append(.init(token: token, hash: hash, 
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
    func add(module id:Module.ID, culture:Packages.Index, fasces:Fasces) 
        -> Atom<Module>.Position
    {
        if let existing:Atom<Module>.Position = fasces.modules.find(id)
        {
            return existing 
        }
        else 
        {
            return self.modules
                .insert(id, culture: culture, Module.init(id:culture:))
                .positioned(self.index)
        }
    }
    mutating 
    func add(graph:SymbolGraph, namespaces:__owned Namespaces, 
        upstream:[Packages.Index: Package.Pinned],
        fasces:Fasces, 
        stems:inout Route.Stems) 
        -> ModuleInterface
    {
        let linked:Set<Atom<Module>> = namespaces.import()
        let (articles, _extensions):(ModuleInterface.Abstractor<Article>, [Extension]) = self.addExtensions(from: graph, 
            namespace: namespaces.module, 
            trunk: fasces.articles, 
            stems: &stems)
        var symbols:ModuleInterface.Abstractor<Symbol> = self.addSymbols(from: graph, 
            namespaces: namespaces, 
            upstream: upstream, 
            linked: linked,
            trunk: fasces.symbols, 
            stems: &stems)
        
        assert(symbols.count == graph.vertices.count)

        symbols.extend(over: graph.identifiers) 
        {
            if let local:Atom<Symbol> = self.symbols.atoms[$0] 
            {
                return local.positioned(self.index)
            }
            if let local:Atom<Symbol>.Position = fasces.symbols.find($0)
            {
                return local 
            } 
            for upstream:Package.Pinned in upstream.values 
            {
                if  let upstream:Atom<Symbol>.Position = upstream.symbols.find($0), 
                        linked.contains(upstream.culture)
                {
                    return upstream
                }
            }
            return nil 
        }

        return .init(namespaces: _move namespaces, 
            _extensions: _move _extensions,
            articles: _move articles,
            symbols: _move symbols)
    }

    private mutating 
    func addSymbols(from graph:SymbolGraph, namespaces:Namespaces, 
        upstream:[Packages.Index: Package.Pinned], 
        linked:Set<Atom<Module>>,
        trunk:Fasces.SymbolView, 
        stems:inout Route.Stems) 
        -> ModuleInterface.Abstractor<Symbol>
    {
        var positions:[Atom<Symbol>.Position?] = []
            positions.reserveCapacity(graph.identifiers.count)
        for (namespace, vertices):(Module.ID, ArraySlice<SymbolGraph.Vertex<Int>>) in 
            graph.colonies
        {
            // will always succeed for the core subgraph
            guard let namespace:Atom<Module> = namespaces.linked[namespace]?.atom
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
        upstream:[Packages.Index: Package.Pinned], 
        trunk:Fasces.SymbolView, 
        stems:inout Route.Stems)
        -> Atom<Symbol>.Position
    {
        if let existing:Atom<Symbol>.Position = trunk.find(id)
        {
            // swift encodes module names in symbol identifiers, so if a symbol changes culture, 
            // something really weird has happened.
            if existing.culture == culture 
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
            if  let restated:Atom<Symbol>.Position = upstream.symbols.find(id), 
                    linked.contains(restated.culture)
            {
                return restated 
            }
        }
        let atom:Atom<Symbol> = self.symbols.insert(id, culture: culture)
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
        return atom.positioned(self.index)
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

        var positions:[Atom<Article>.Position?] = []
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
        -> Atom<Article>.Position
    {
        // article namespace is always its culture. 
        let stem:Route.Stem = stems.register(components: path.prefix) 
        let leaf:Route.Stem = stems.register(component: path.last)

        let id:Article.ID = .init(culture, stem, leaf)

        if let existing:Atom<Article>.Position = trunk.find(id)
        {
            guard existing.culture == culture 
            else 
            {
                fatalError("unreachable")
            }
            return existing 
        }
        let atom:Atom<Article> = self.articles.insert(id, culture: culture)
        {
            (id:Article.ID, _:Atom<Article>) in 
            .init(id: id, path: path)
        }
        return atom.positioned(self.index)
    }
}
