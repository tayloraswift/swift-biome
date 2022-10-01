import SymbolGraphs
import SymbolSource
import Versions

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
    func commit(_ commit:__owned Commit, token:UInt, 
        pins:__owned [Packages.Index: Version]) -> Version
    {
        let revision:Version.Revision = self.revisions.endIndex
        self.revisions.append(.init(commit: commit, token: token,
            ring: .init(
                modules: self.modules.endIndex, 
                symbols: self.symbols.endIndex, 
                articles: self.articles.endIndex), 
            pins: pins))
        return .init(self.index, revision)
    }
}
extension Branch 
{
    mutating 
    func addModule(_ namespace:ModuleIdentifier, nationality:Packages.Index, local:Fasces) 
        -> Atom<Module>.Position
    {
        if let existing:Atom<Module>.Position = local.modules.find(namespace)
        {
            return existing 
        }
        else 
        {
            return self.modules
                .insert(namespace, culture: nationality, Module.init(id:culture:))
                .positioned(self.index)
        }
    }

    mutating 
    func addSymbols(from graph:SymbolGraph, visible:Set<Atom<Module>>,
        context:ModuleUpdateContext, 
        stems:inout Route.Stems) -> ModuleInterface.Abstractor<Symbol>
    {
        var positions:[Atom<Symbol>.Position?] = []
            positions.reserveCapacity(graph.identifiers.count)
        for (namespace, vertices):(ModuleIdentifier, ArraySlice<SymbolGraph.Vertex<Int>>) in 
            graph.colonies
        {
            // will always succeed for the core subgraph
            guard let namespace:Atom<Module> = context.linked[namespace]?.atom
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
                    culture: context.culture, 
                    namespace: namespace, 
                    visible: visible, 
                    vertex: vertex, 
                    context: context, 
                    stems: &stems))
            }
            let end:Symbol.Offset = self.symbols.endIndex 
            if start < end
            {
                if self.index == context.module.branch 
                {
                    self.modules[contemporary: context.culture].symbols
                        .append((start ..< end, namespace))
                }
                else 
                {
                    self.modules.divergences[context.culture, default: .init()].symbols
                        .append((start ..< end, namespace))
                }
            }
        }
        return .init(_move positions)
    }
    private mutating 
    func addSymbol(_ id:SymbolIdentifier, culture:Atom<Module>, namespace:Atom<Module>, 
        visible:Set<Atom<Module>>,
        vertex:SymbolGraph.Vertex<Int>,
        context:ModuleUpdateContext,
        stems:inout Route.Stems)
        -> Atom<Symbol>.Position
    {
        if let existing:Atom<Symbol>.Position = context.local.symbols.find(id)
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
        for upstream:Package.Pinned in context.upstream.values 
        {
            if  let restated:Atom<Symbol>.Position = upstream.symbols.find(id), 
                    visible.contains(restated.culture)
            {
                return restated 
            }
        }
        let atom:Atom<Symbol> = self.symbols.insert(id, culture: culture)
        {
            (id:SymbolIdentifier, _:Atom<Symbol>) in 
            let route:Route = .init(namespace, 
                      stems.register(components: vertex.path.prefix), 
                .init(stems.register(component:  vertex.path.last), 
                orientation: vertex.shape.orientation))
            // if the symbol could inherit features, generate a stem 
            // for its children from its full path. this stem will only 
            // go to waste if a concretetype is completely uninhabited, 
            // which is very rare.
            let kind:Symbol.Kind 
            switch vertex.shape
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
    mutating 
    func addExtensions(from graph:SymbolGraph, namespace:Atom<Module>.Position, 
        trunk:Fasces.ArticleView, 
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
                    culture: namespace.atom, 
                    trunk: trunk, 
                    stems: &stems))
            
            case    (.implicit(_)?, _?), (nil, _): 
                positions.append(nil)
            }
        }
        let end:Article.Offset = self.articles.endIndex
        if start < end
        {
            if self.index == namespace.branch 
            {
                self.modules[contemporary: namespace.atom].articles
                    .append(start ..< end)
            }
            else 
            {
                self.modules.divergences[namespace.atom, default: .init()].articles
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
