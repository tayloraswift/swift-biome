import SymbolGraphs
import SymbolSource
import Versions
import Sediment


typealias OriginalHead<Value> = Sediment<Version.Revision, Value>.Head
/// A descriptor for a field of a symbol that was founded in a different 
/// branch than the branch the descriptor lives in, whose value has diverged 
/// from the value it held when the descriptor’s branch was forked from 
/// its trunk.
struct AlternateHead<Value>
{
    var head:Sediment<Version.Revision, Value>.Head
    /// The first revision in which this field diverged from its parent branch.
    let since:Version.Revision
}
enum PeriodHead<Value>
{
    case original(OriginalHead<Value>?)
    case alternate(AlternateHead<Value>?)
}

extension Optional
{
    subscript<Value>(since revision:Version.Revision) -> OriginalHead<Value>?
        where Wrapped == AlternateHead<Value>
    {
        _read
        {
            yield self?.head
        }
        _modify
        {
            if  let existing:AlternateHead<Value> = self 
            {
                var head:OriginalHead<Value>? = existing.head
                let revision:Version.Revision = existing.since
                yield &head
                self = head.map { .init(head: $0, since: revision) }
            }
            else 
            {
                var head:OriginalHead<Value>? = nil
                yield &head 
                self = head.map { .init(head: $0, since: revision) }
            }
        }
    }
}

protocol PluralAxis<Key, Element>
{
    associatedtype Key
    associatedtype Element:BranchElement

    typealias Field<Value> = FieldAccessor<Element, Key, Value>
}
protocol BranchAxis<Key, Element>:PluralAxis
{
    subscript<Value>(field:Field<Value>) -> OriginalHead<Value>?
    {
        get
    }
    subscript<Value>(field:Field<Value>, 
        since revision:Version.Revision) -> OriginalHead<Value>?
    {
        get set
    }
}
protocol PeriodAxis<Key, Element>:PluralAxis
{
    subscript<Value>(field:Field<Value>) -> PeriodHead<Value>
    {
        get
    }
}

extension Sediment where Instant == Version.Revision, Value:Equatable
{
    mutating 
    func deposit<Trunk, Axis>(inserting value:__owned Value,
        revision:Version.Revision,
        field:Axis.Field<Value>,
        trunk:Trunk,
        axis:inout Axis) 
        where   Trunk:FieldViews, Axis:BranchAxis, 
                Trunk.Axis.Element == Axis.Element, 
                Trunk.Axis.Key == Axis.Key,
                Trunk.Value == Value
    {
        let current:OriginalHead<Value>? = axis[field]

        if  let current:OriginalHead<Value>
        {
            guard self[current.index].value != value
            else
            {
                return
            }
        }
        else if let existing:Value = trunk.value(of: field)
        {
            guard existing != value
            else
            {
                return
            }
        }

        axis[field, since: revision] = self.deposit(value, time: revision, over: current)
    }
}

extension Branch
{
    mutating 
    func updateMetadata(interface:PackageInterface, builder:SurfaceBuilder)
    {
        for missing:Atom<Module> in builder.previous.modules 
        {
            self.history.metadata.modules.deposit(inserting: nil,
                revision: interface.revision, 
                field: .metadata(of: missing), 
                trunk: interface.local.metadata.modules,
                axis: &self.modules)
        }
        for missing:Atom<Article> in builder.previous.articles 
        {
            self.history.metadata.articles.deposit(inserting: nil,
                revision: interface.revision, 
                field: .metadata(of: missing), 
                trunk: interface.local.metadata.articles,
                axis: &self.articles)
        }
        for missing:Atom<Symbol> in builder.previous.symbols
        {
            self.history.metadata.symbols.deposit(inserting: nil, 
                revision: interface.revision, 
                field: .metadata(of: missing), 
                trunk: interface.local.metadata.symbols,
                axis: &self.symbols)
        }
        for missing:Diacritic in builder.previous.overlays
        {
            self.history.metadata.overlays.deposit(inserting: nil, 
                revision: interface.revision, 
                field: .metadata(of: missing),
                trunk: interface.local.metadata.overlays,
                axis: &self.overlays)
        }
        
        for module:ModuleInterface in interface
        {
            self.history.metadata.modules.deposit(
                inserting: .init(dependencies: module.namespaces.dependencies()),
                revision: interface.revision, 
                field: .metadata(of: module.culture), 
                trunk: interface.local.metadata.modules,
                axis: &self.modules)
        }
        for (article, metadata):(Atom<Article>, Article.Metadata) in 
            builder.articles
        {
            self.history.metadata.articles.deposit(
                inserting: metadata,
                revision: interface.revision, 
                field: .metadata(of: article), 
                trunk: interface.local.metadata.articles,
                axis: &self.articles) 
        }
        for (symbol, metadata):(Atom<Symbol>, Symbol.Metadata) in 
            builder.symbols
        {
            self.history.metadata.symbols.deposit(
                inserting: metadata,
                revision: interface.revision, 
                field: .metadata(of: symbol), 
                trunk: interface.local.metadata.symbols,
                axis: &self.symbols) 
        }
        for (diacritic, metadata):(Diacritic, Overlay.Metadata) in 
            builder.overlays
        {
            self.history.metadata.overlays.deposit(
                inserting: metadata, 
                revision: interface.revision, 
                field: .metadata(of: diacritic), 
                trunk: interface.local.metadata.overlays,
                axis: &self.overlays)
        }
    }

    mutating 
    func updateTopLevelSymbols(_ topLevelSymbols:__owned Set<Atom<Symbol>>, 
        interface:ModuleInterface, 
        revision:Version.Revision)
    {
        self.history.data.topLevelSymbols.deposit(
            inserting: topLevelSymbols, 
            revision: revision, 
            field: .topLevelSymbols(of: interface.culture), 
            trunk: interface.local.data.topLevelSymbols,
            axis: &self.modules)
    }
    mutating 
    func updateTopLevelArticles(_ topLevelArticles:__owned Set<Atom<Article>>, 
        interface:ModuleInterface, 
        revision:Version.Revision)
    {
        self.history.data.topLevelArticles.deposit(
            inserting: topLevelArticles, 
            revision: revision, 
            field: .topLevelArticles(of: interface.culture), 
            trunk: interface.local.data.topLevelArticles,
            axis: &self.modules)
    }
    mutating 
    func updateDeclarations(graph:__owned SymbolGraph, 
        interface:ModuleInterface, 
        revision:Version.Revision)
    {
        for (position, vertex):(Atom<Symbol>.Position?, SymbolGraph.Vertex<Int>) in 
            zip(interface.citizenSymbols, graph.vertices)
        {
            guard let element:Atom<Symbol> = position?.atom
            else 
            {
                continue 
            }
            let declaration:Declaration<Atom<Symbol>> = vertex.declaration.flatMap 
            {
                if let target:Atom<Symbol> = interface.symbols[$0]?.atom
                {
                    return target 
                }
                // ignore warnings related to c-language symbols 
                let id:SymbolIdentifier = graph.identifiers[$0]
                if case .swift = id.language 
                {
                    print("warning: unknown id '\(id)' (in declaration for symbol '\(vertex.path)')")
                }
                return nil
            }
            self.history.data.declarations.deposit(inserting: declaration, 
                revision: revision, 
                field: .declaration(of: element), 
                trunk: interface.local.data.declarations,
                axis: &self.symbols)
        }
    }

    mutating 
    func updateDocumentation(_ literature:__owned Literature, interface:PackageInterface)
    {
        for (key, documentation):(Atom<Module>, DocumentationExtension<Never>)
            in literature.modules 
        {
            self.history.data.standaloneDocumentation.deposit(inserting: documentation, 
                revision: interface.revision, 
                field: .documentation(of: key), 
                trunk: interface.local.data.moduleDocumentation,
                axis: &self.modules)
        }
        for (key, documentation):(Atom<Article>, DocumentationExtension<Never>)
            in literature.articles 
        {
            self.history.data.standaloneDocumentation.deposit(inserting: documentation, 
                revision: interface.revision, 
                field: .documentation(of: key), 
                trunk: interface.local.data.articleDocumentation,
                axis: &self.articles)
        }
        for (key, documentation):(Atom<Symbol>, DocumentationExtension<Atom<Symbol>>)
            in literature.symbols 
        {
            self.history.data.cascadingDocumentation.deposit(inserting: documentation, 
                revision: interface.revision, 
                field: .documentation(of: key), 
                trunk: interface.local.data.symbolDocumentation,
                axis: &self.symbols)
        }
    }
}


public 
struct Branch:Identifiable, Sendable 
{
    struct _History
    {
        struct Metadata
        {
            var modules:Sediment<Version.Revision, Module.Metadata?>
            var articles:Sediment<Version.Revision, Article.Metadata?>
            var symbols:Sediment<Version.Revision, Symbol.Metadata?>
            var overlays:Sediment<Version.Revision, Overlay.Metadata?>

            init()
            {
                self.modules = .init()
                self.articles = .init()
                self.symbols = .init()
                self.overlays = .init()
            }
        }
        struct Data
        {
            var topLevelArticles:Sediment<Version.Revision, Set<Atom<Article>>>
            var topLevelSymbols:Sediment<Version.Revision, Set<Atom<Symbol>>>
            var declarations:Sediment<Version.Revision, Declaration<Atom<Symbol>>>

            var standaloneDocumentation:Sediment<Version.Revision, DocumentationExtension<Never>>
            var cascadingDocumentation:Sediment<Version.Revision, DocumentationExtension<Atom<Symbol>>>
            init()
            {
                self.topLevelArticles = .init()
                self.topLevelSymbols = .init()
                self.declarations = .init()

                self.standaloneDocumentation = .init()
                self.cascadingDocumentation = .init()
            }
        }

        var metadata:Metadata
        var data:Data

        init()
        {
            self.metadata = .init()
            self.data = .init()
        }
    }

    public 
    let id:Tag
    let index:Version.Branch

    let fork:Version?
    var revisions:Revisions

    var modules:IntrinsicBuffer<Module>,
        articles:IntrinsicBuffer<Article>, 
        symbols:IntrinsicBuffer<Symbol>
    var overlays:Overlays

    var routes:[Route: Stack]

    var history:_History

    init(id:ID, index:Version.Branch, fork:(version:Version, ring:Ring)?)
    {
        self.id = id 
        self.index = index 

        self.fork = fork?.version

        self.revisions = .init()
        
        self.overlays = .init()
        self.articles = .init(startIndex: fork?.ring.articles ?? 0)
        self.symbols = .init(startIndex: fork?.ring.symbols ?? 0)
        self.modules = .init(startIndex: fork?.ring.modules ?? 0)
        self.routes = [:]

        self.history = .init()
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
            modules: self.modules[..<ring.modules], 
            articles: self.articles[..<ring.articles],
            symbols: self.symbols[..<ring.symbols], 
            overlays: self.overlays,
            history: self.history,
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
        trunk:Fasces.Articles, 
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
    func addArticle(_ path:Path, culture:Atom<Module>, trunk:Fasces.Articles, 
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
