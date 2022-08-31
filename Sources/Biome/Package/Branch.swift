import PackageResolution

enum _Dependency:Sendable 
{
    case available(_Version)
    case unavailable(Branch.ID, String)
}
enum _DependencyError:Error 
{
    case package                                (unavailable:Package.ID)
    case pin                                    (unavailable:Package.ID)
    case version           (unavailable:(Branch.ID, String), Package.ID)
    case module (unavailable:Module.ID, (Branch.ID, String), Package.ID)
    case target (unavailable:Module.ID,  Branch.ID)
}
struct _Version:Hashable, Sendable 
{
    struct Branch:Hashable, Sendable 
    {
        let index:Int 

        init(_ index:Int)
        {
            self.index = index
        }
    }
    struct Revision:Hashable, Strideable, Sendable
    {
        let index:Int 

        init(_ index:Int)
        {
            self.index = index
        }

        static 
        func < (lhs:Self, rhs:Self) -> Bool
        {
            lhs.index < rhs.index
        }
        func advanced(by stride:Int.Stride) -> Self 
        {
            .init(self.index.advanced(by: stride))
        }
        func distance(to other:Self) -> Int.Stride
        {
            self.index.distance(to: other.index)
        }
    }

    var branch:Branch
    var revision:Revision

    init(_ branch:Branch, _ revision:Revision)
    {
        self.branch = branch 
        self.revision = revision 
    }
}
struct Trunk:Sendable 
{
    let branch:_Version.Branch
    let modules:Branch.Buffer<Module>.SubSequence, 
        symbols:Branch.Buffer<Symbol>.SubSequence,
        articles:Branch.Buffer<Article>.SubSequence
    
    func position<Element>(_ index:Element.Index) -> Tree.Position<Element> 
        where Element:BranchElement 
    {
        .init(index, branch: self.branch)
    }
}
public 
struct Branch:Identifiable, Sendable 
{
    public 
    enum ID:Hashable, Sendable 
    {
        case master 
        case custom(String)
        case semantic(SemanticVersion)

        init(_ requirement:PackageResolution.Requirement)
        {
            switch requirement 
            {
            case .version(let version): 
                self = .semantic(version)
            case .branch("master"), .branch("main"): 
                self = .master
            case .branch(let name): 
                self = .custom(name)
            }
        }
    }
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
    let id:ID
    let index:_Version.Branch

    let fork:_Version?
    var heads:Package.Heads
    private 
    var revisions:[Revision]

    private(set)
    var newModules:Buffer<Module>, 
        newSymbols:Buffer<Symbol>,
        newArticles:Buffer<Article>
    private(set)
    var updatedModules:[Module.Index: Module.Heads], 
        updatedSymbols:[Symbol.Index: Symbol.Heads], 
        updatedArticles:[Article.Index: Article.Heads]
    
    var startIndex:_Version.Revision 
    {
        .init(self.revisions.startIndex)
    }
    var endIndex:_Version.Revision 
    {
        .init(self.revisions.endIndex)
    }
    var indices:Range<_Version.Revision> 
    {
        self.startIndex ..< self.endIndex
    }
    subscript(revision:_Version.Revision) -> Revision
    {
        _read 
        {
            yield  self.revisions[revision.index]
        }
        _modify
        {
            yield &self.revisions[revision.index]
        }
    }

    init(id:ID, index:_Version.Branch, fork:(version:_Version, ring:Ring)?)
    {
        self.id = id 
        self.index = index 

        self.fork = fork?.version
        self.heads = .init() 
        self.revisions = []
        
        self.newModules = .init(startIndex: fork?.ring.modules ?? 0)
        self.newSymbols = .init(startIndex: fork?.ring.symbols ?? 0)
        self.newArticles = .init(startIndex: fork?.ring.articles ?? 0)

        self.updatedModules = [:]
        self.updatedSymbols = [:]
        self.updatedArticles = [:]
    }
    
    subscript(prefix:PartialRangeUpTo<_Version.Revision>) -> Trunk 
    {
        let ring:Ring = self.revisions[prefix.upperBound.index].ring
        return .init(branch: self.index, 
            modules: self.newModules[..<ring.modules], 
            symbols: self.newSymbols[..<ring.symbols], 
            articles: self.newArticles[..<ring.articles])
    }
    subscript(_:UnboundedRange) -> Trunk 
    {
        return .init(branch: self.index, 
            modules: self.newModules[...], 
            symbols: self.newSymbols[...], 
            articles: self.newArticles[...])
    }

    mutating 
    func commit(_ hash:String, pins:[Package.Index: _Version]) -> _Version
    {
        let commit:_Version.Revision = self.endIndex
        self.revisions.append(.init(hash: hash, 
            ring: .init(
                modules: self.newModules.endIndex, 
                symbols: self.newSymbols.endIndex, 
                articles: self.newArticles.endIndex), 
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

extension Sequence<Trunk> 
{
    func find(module:Module.ID) -> Tree.Position<Module>? 
    {
        for trunk:Trunk in self 
        {
            if let module:Module.Index = trunk.modules.opaque(of: module)
            {
                return .init(module, branch: trunk.branch)
            }
        }
        return nil
    }
    func find(symbol:Symbol.ID) -> Tree.Position<Symbol>? 
    {
        for trunk:Trunk in self 
        {
            if let symbol:Symbol.Index = trunk.symbols.opaque(of: symbol)
            {
                return .init(symbol, branch: trunk.branch)
            }
        }
        return nil
    }
    func find(article:Article.ID) -> Tree.Position<Article>? 
    {
        for trunk:Trunk in self 
        {
            if let article:Article.Index = trunk.articles.opaque(of: article)
            {
                return .init(article, branch: trunk.branch)
            }
        }
        return nil
    }
}
extension Branch 
{
    mutating 
    func add(module id:Module.ID, culture:Package.Index, trunks:[Trunk]) 
        -> Tree.Position<Module>
    {
        if let existing:Tree.Position<Module> = trunks.find(module: id)
        {
            return existing 
        }
        let index:Module.Index = self.newModules.insert(id, culture: culture, 
            Module.init(id:index:))
        return self.position(index)
    }
    mutating 
    func add(graph:SymbolGraph, namespaces:Namespaces, trunks:[Trunk], stems:inout Route.Stems) 
        -> (_Abstractor, [Extension])
    {
        let (articles, _rendered):([Tree.Position<Article>?], [Extension]) = self.addExtensions(from: graph, 
            namespace: namespaces.current, 
            trunks: trunks, 
            stems: &stems)
        let symbols:[Tree.Position<Symbol>?] = self.addSymbols(from: graph, 
            namespaces: namespaces, 
            trunks: trunks, 
            stems: &stems)
        
        assert(symbols.count == graph.vertices.count)

        var abstractor:_Abstractor = .init(symbols: _move symbols, articles: articles, 
            culture: namespaces.current.culture)
            abstractor.extend(over: graph.identifiers, by: trunks.find(symbol:))
        return (abstractor, _rendered)
    }

    private mutating 
    func addSymbols(from graph:SymbolGraph, namespaces:Namespaces, trunks:[Trunk], 
        stems:inout Route.Stems) 
        -> [Tree.Position<Symbol>?]
    {
        var positions:[Tree.Position<Symbol>?] = []
            positions.reserveCapacity(graph.identifiers.count)
        for (namespace, vertices):(Module.ID, ArraySlice<SymbolGraph.Vertex<Int>>) in 
            graph.colonies
        {
            // will always succeed for the core subgraph
            guard let namespace:Module.Index = namespaces.positions[namespace]?.index
            else 
            {
                print("warning: ignored colonial symbolgraph '\(graph.id)@\(namespace)'")
                print("note: '\(namespace)' is not a known dependency of '\(graph.id)'")

                positions.append(contentsOf: repeatElement(nil, count: vertices.count))
                continue 
            }
            
            let start:Symbol.Offset = self.newSymbols.endIndex
            for (offset, vertex):(Int, SymbolGraph.Vertex<Int>) in 
                zip(vertices.indices, vertices)
            {
                positions.append(self.addSymbol(graph.identifiers[offset], 
                    culture: namespaces.current.culture, 
                    trunks: trunks, 
                    namespace: namespace, 
                    community: vertex.community, 
                    path: vertex.path, 
                    stems: &stems))
            }
            let end:Symbol.Offset = self.newSymbols.endIndex 
            if start < end
            {
                let colony:Module.Colony = .init(namespace: namespace, range: start ..< end)
                if self.index == namespaces.current.position.branch 
                {
                    self.newModules[local: namespaces.current.culture].heads.symbols
                        .append(colony)
                }
                else 
                {
                    self.updatedModules[namespaces.current.culture, default: .init()].symbols
                        .append(colony)
                }
            }
        }
        return positions
    }
    private mutating 
    func addSymbol(_ id:Symbol.ID, culture:Module.Index, trunks:[Trunk], 
        namespace:Module.Index, 
        community:Community, 
        path:Path, 
        stems:inout Route.Stems)
        -> Tree.Position<Symbol>
    {
        if let existing:Tree.Position<Symbol> = trunks.find(symbol: id)
        {
            guard existing.index.module == culture 
            else 
            {
                // swift encodes module names in symbol identifiers, so if a symbol changes culture, 
                // something really weird has happened.
                fatalError("symbol with id '\(id)' has already been registered in a different module! symbolgraph may have been corrupted!")
            }
            return existing 
        }
        let index:Symbol.Index = self.newSymbols.insert(id, culture: culture)
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
    func addExtensions(from graph:SymbolGraph, namespace:Namespace, trunks:[Trunk], 
        stems:inout Route.Stems) 
        -> ([Tree.Position<Article>?], [Extension])
    {
        let _extensions:[Extension] = graph.extensions.map
        {
            .init(markdown: $0.source, name: $0.name)
        }

        var positions:[Tree.Position<Article>?] = []
            positions.reserveCapacity(graph.extensions.count)
        let start:Article.Offset = self.newArticles.endIndex
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
                    trunks: trunks, 
                    stems: &stems))
            
            case    (.implicit(_)?, _?), (nil, _): 
                positions.append(nil)
            }
        }
        let end:Article.Offset = self.newArticles.endIndex
        if start < end
        {
            if self.index == namespace.position.branch 
            {
                self.newModules[local: namespace.culture].heads.articles
                    .append(start ..< end)
            }
            else 
            {
                self.updatedModules[namespace.culture, default: .init()].articles
                    .append(start ..< end)
            }
        }
        return (positions, _extensions)
    }
    private mutating 
    func addArticle(_ id:Article.ID, culture:Module.Index, trunks:[Trunk], 
        stems:inout Route.Stems)
        -> Tree.Position<Article>
    {
        if let existing:Tree.Position<Article> = trunks.find(article: id)
        {
            guard existing.index.module == culture 
            else 
            {
                fatalError("unreachable")
            }
            return existing 
        }
        let index:Article.Index = self.newArticles.insert(id, culture: culture)
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
