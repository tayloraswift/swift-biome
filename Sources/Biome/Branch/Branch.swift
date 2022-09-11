import PackageResolution

enum _Dependency:Sendable 
{
    case available(_Version)
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
    // struct Date:Hashable, Sendable 
    // {
    //     var year:UInt16 
    //     var month:UInt16 
    //     var day:UInt16 
    //     var hour:UInt8
    // }
    struct Ring:Sendable 
    {
        //let revision:Int 
        let modules:Module.Offset
        let symbols:Symbol.Offset
        let articles:Article.Offset
    }
    struct Revision:Sendable 
    {
        let hash:String 
        let ring:Ring
        let pins:[Package.Index: _Version]
        var consumers:[Package.Index: Set<_Version>]

        init(hash:String, ring:Ring, pins:[Package.Index: _Version])
        {
            self.hash = hash 
            self.ring = ring 
            self.pins = pins 
            self.consumers = [:]
        }
    }

    public 
    let id:String
    let index:_Version.Branch

    let fork:_Version?
    var heads:Package.Heads
    private 
    var revisions:[Revision]

    var foreign:[Diacritic: Symbol.ForeignDivergence]
    var articles:Buffer<Article>, 
        symbols:Buffer<Symbol>,
        modules:Buffer<Module>
    var routes:[Route.Key: Stack]

    var _head:_Version.Revision? 
    {
        self.indices.last
    }

    var startIndex:_Version.Revision 
    {
        .init(.init(self.revisions.startIndex))
    }
    var endIndex:_Version.Revision 
    {
        .init(.init(self.revisions.endIndex))
    }
    var indices:Range<_Version.Revision> 
    {
        self.startIndex ..< self.endIndex
    }
    subscript(revision:_Version.Revision) -> Revision
    {
        _read 
        {
            yield  self.revisions[.init(revision.index)]
        }
        _modify
        {
            yield &self.revisions[.init(revision.index)]
        }
    }

    init(id:ID, index:_Version.Branch, fork:(version:_Version, ring:Ring)?)
    {
        self.id = id 
        self.index = index 

        self.fork = fork?.version
        self.heads = .init() 
        self.revisions = []
        
        self.foreign = [:]
        self.articles = .init(startIndex: fork?.ring.articles ?? 0)
        self.symbols = .init(startIndex: fork?.ring.symbols ?? 0)
        self.modules = .init(startIndex: fork?.ring.modules ?? 0)
        self.routes = [:]
    }
    
    subscript(range:PartialRangeThrough<_Version.Revision>) -> Fascis
    {
        let ring:Ring = self[range.upperBound].ring
        return .init(
            articles: self.articles[..<ring.articles],
            symbols: self.symbols[..<ring.symbols], 
            modules: self.modules[..<ring.modules], 
            foreign: self.foreign, 
            routes: self.routes, 
            branch: self.index,
            limit: range.upperBound)
    }
    // subscript(_:UnboundedRange) -> Fascis 
    // {
    //     return .init(branch: self.index, 
    //         routes: self.routes[...],
    //         modules: self.modules[...],
    //         symbols: self.symbols[...],
    //         articles: self.articles[...])
    // }

    mutating 
    func commit(_ hash:String, pins:[Package.Index: _Version]) -> _Version
    {
        let commit:_Version.Revision = self.endIndex
        self.revisions.append(.init(hash: hash, 
            ring: .init(
                modules: self.modules.endIndex, 
                symbols: self.symbols.endIndex, 
                articles: self.articles.endIndex), 
            pins: pins))
        return .init(self.index, commit)
    }

    // FIXME: this could be made a lot more efficient
    func find(_ hash:String) -> _Version.Revision?
    {
        for revision:_Version.Revision in self.indices
        {
            if self[revision].hash == hash 
            {
                return revision 
            }
        }
        return nil 
    }

    func position<Element>(_ index:Element.Index) -> Tree.Position<Element> 
        where Element:BranchElement 
    {
        .init(index, branch: self.index)
    }
}

extension Branch 
{
    mutating 
    func add(module id:Module.ID, culture:Package.Index, fasces:Fasces) 
        -> Tree.Position<Module>
    {
        if let existing:Tree.Position<Module> = fasces.modules.find(id)
        {
            return existing 
        }
        let index:Position<Module> = self.modules.insert(id, culture: culture, 
            Module.init(id:index:))
        return self.position(index)
    }
    mutating 
    func add(graph:SymbolGraph, namespaces:__owned Namespaces, fasces:Fasces, 
        stems:inout Route.Stems) 
        -> ModuleInterface
    {
        let (articles, _extensions):(ModuleInterface.Abstractor<Article>, [Extension]) = self.addExtensions(from: graph, 
            namespace: namespaces.module, 
            trunk: fasces.articles, 
            stems: &stems)
        var symbols:ModuleInterface.Abstractor<Symbol> = self.addSymbols(from: graph, 
            namespaces: namespaces, 
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
    func addSymbols(from graph:SymbolGraph, namespaces:Namespaces, trunk:Fasces.SymbolView, 
        stems:inout Route.Stems) 
        -> ModuleInterface.Abstractor<Symbol>
    {
        var positions:[Tree.Position<Symbol>?] = []
            positions.reserveCapacity(graph.identifiers.count)
        for (namespace, vertices):(Module.ID, ArraySlice<SymbolGraph.Vertex<Int>>) in 
            graph.colonies
        {
            // will always succeed for the core subgraph
            guard let namespace:Position<Module> = namespaces.linked[namespace]?.contemporary
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
                    trunk: trunk, 
                    namespace: namespace, 
                    community: vertex.community, 
                    path: vertex.path, 
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
    func addSymbol(_ id:Symbol.ID, culture:Position<Module>, trunk:Fasces.SymbolView, 
        namespace:Position<Module>, 
        community:Community, 
        path:Path, 
        stems:inout Route.Stems)
        -> Tree.Position<Symbol>
    {
        if let existing:Tree.Position<Symbol> = trunk.find(id)
        {
            guard existing.contemporary.module == culture 
            else 
            {
                // swift encodes module names in symbol identifiers, so if a symbol changes culture, 
                // something really weird has happened.
                fatalError("symbol with id '\(id)' has already been registered in a different module! symbolgraph may have been corrupted!")
            }
            return existing 
        }
        let index:Symbol.Index = self.symbols.insert(id, culture: culture)
        {
            (id:Symbol.ID, _:Symbol.Index) in 
            let route:Route.Key = .init(namespace, 
                        stems.register(components: path.prefix), 
                .init(stems.register(component:  path.last), 
                orientation: community.orientation))
            // if the symbol could inherit features, generate a stem 
            // for its children from its full path. this stem will only 
            // go to waste if a concretetype is completely uninhabited, 
            // which is very rare.
            let kind:Symbol.Kind 
            switch community
            {
            case .associatedtype: 
                kind = .associatedtype 
            case .concretetype(let concrete): 
                kind = .concretetype(concrete, path: path.prefix.isEmpty ? 
                    route.leaf.stem : stems.register(components: path))
            case .callable(let callable): 
                kind = .callable(callable)
            case .global(let global): 
                kind = .global(global)
            case .protocol: 
                kind = .protocol 
            case .typealias: 
                kind = .typealias
            }
            return .init(id: id, path: path, kind: kind, route: route)
        }
        return self.position(index)
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

        var positions:[Tree.Position<Article>?] = []
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
                positions.append(self.addArticle(.init(namespace.id, path), 
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
    func addArticle(_ id:Article.ID, culture:Position<Module>, trunk:Fasces.ArticleView, 
        stems:inout Route.Stems)
        -> Tree.Position<Article>
    {
        if let existing:Tree.Position<Article> = trunk.find(id)
        {
            guard existing.contemporary.module == culture 
            else 
            {
                fatalError("unreachable")
            }
            return existing 
        }
        let index:Article.Index = self.articles.insert(id, culture: culture)
        {
            (id:Article.ID, index:Article.Index) in 
            // article namespace is always its culture. 
            let route:Route.Key = .init(index.module, 
                        stems.register(components: id.path.prefix), 
                .init(stems.register(component:  id.path.last), 
                orientation: .straight))
            return .init(id: id, route: route)
        }
        return self.position(index)
    }
}
