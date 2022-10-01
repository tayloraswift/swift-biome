import SymbolGraphs
import SymbolSource

struct PackageInterface
{
    let local:Fasces
    let version:Version
    private
    var storage:[BasisElement]

    init(capacity:Int = 0, version:Version, local:Fasces)
    {
        self.local = local
        self.version = version
        self.storage = []
        self.storage.reserveCapacity(capacity)
    }

    var revision:Version.Revision
    {
        self.version.revision
    }
}
extension PackageInterface:RandomAccessCollection
{
    var startIndex:Int
    {
        self.storage.startIndex
    }
    var endIndex:Int
    {
        self.storage.endIndex
    }
    subscript(index:Int) -> ModuleInterface
    {
        let element:BasisElement = self.storage[index]
        return .init(context: .init(namespaces: element.namespaces, 
                upstream: element.upstream, 
                local: self.local), 
            _extensions: element._cachedMarkdown, 
            articles: element.articles, 
            symbols: element.symbols)
    }
}
extension PackageInterface
{
    private
    struct BasisElement
    {
        let namespaces:Namespaces
        let upstream:[Packages.Index: Package.Pinned]

        let articles:ModuleInterface.Abstractor<Article>
        let symbols:ModuleInterface.Abstractor<Symbol>

        // this does not belong here! once AOT article rendering lands in the `SymbolGraphs` module, 
        // we can get rid of it
        let _cachedMarkdown:[Extension]

        init(articles:ModuleInterface.Abstractor<Article>,
            symbols:ModuleInterface.Abstractor<Symbol>,
            _cachedMarkdown:[Extension],
            context:__shared ModuleUpdateContext)
        {
            self.namespaces = context.namespaces
            self.upstream = context.upstream

            self.articles = articles
            self.symbols = symbols
            self._cachedMarkdown = _cachedMarkdown
        }
    }
}
extension PackageInterface
{
    mutating 
    func update(_ branch:inout Branch, with graph:SymbolGraph,
        context:ModuleUpdateContext,
        stems:inout Route.Stems) -> ModuleInterface
    {
        let visible:Set<Atom<Module>> = context.namespaces.import()
        let (articles, _extensions):(ModuleInterface.Abstractor<Article>, [Extension]) = branch.addExtensions(from: graph, 
            namespace: context.module, 
            trunk: context.local.articles, 
            stems: &stems)
        var symbols:ModuleInterface.Abstractor<Symbol> = branch.addSymbols(from: graph, 
            visible: visible,
            context: context,
            stems: &stems)
        
        assert(symbols.count == graph.vertices.count)

        symbols.extend(over: graph.identifiers) 
        {
            if let local:Atom<Symbol> = branch.symbols.atoms[$0] 
            {
                return local.positioned(branch.index)
            }
            if let local:Atom<Symbol>.Position = context.local.symbols.find($0)
            {
                return local 
            } 
            for upstream:Package.Pinned in context.upstream.values 
            {
                if  let upstream:Atom<Symbol>.Position = upstream.symbols.find($0), 
                        visible.contains(upstream.culture)
                {
                    return upstream
                }
            }
            return nil 
        }

        let last:Int = self.storage.endIndex
        self.storage.append(.init(articles: articles, symbols: symbols, 
            _cachedMarkdown: _extensions, 
            context: context))
        return self[last]
    }
}