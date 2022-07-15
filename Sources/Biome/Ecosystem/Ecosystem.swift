import DOM
import Resources

public
struct Ecosystem:Sendable 
{    
    @usableFromInline 
    enum Index:Hashable, Sendable
    {
        case package(Package.Index)
        case module(Module.Index)
        case article(Article.Index)
        case composite(Symbol.Composite)
        
        static 
        func symbol(_ natural:Symbol.Index) -> Self 
        {
            .composite(.init(natural: natural))
        }
    }
    
    struct Link:Hashable, Sendable
    {
        enum Expansion:Hashable, Sendable 
        {
            case package(Package.Index)
            case article(Article.Index)
            case module(Module.Index, [Symbol.Composite] = [])
            case composite           ([Symbol.Composite])
        }
        
        let target:Index 
        let visible:Int
        
        init(_ target:Index, visible:Int)
        {
            self.target = target 
            self.visible = visible
        }
    }
    
    /* func describe(_ error:LinkResolutionError) -> String 
    {
        switch error 
        {
        case .none(let expression): 
            return "symbol link '\(expression)' matches no known symbols"
        case .many(let expression, let possibilities):
            return 
                """
                symbol link '\(expression)' matches multiple symbols:
                \(possibilities.enumerated().map 
                {
                    let symbol:Symbol = self[$0.1.base]
                    if let host:Symbol.Index = $0.1.host 
                    {
                        return "\($0.0). \(self[host].path).\(symbol.name) (\(symbol.id.string))"
                    }
                    else 
                    {
                        return "\($0.0). \(symbol.path) (\(symbol.id.string))"
                    }
                }.joined(separator: "\n"))
                """
        }
    } */
    
    let logo:[UInt8]
    
    private(set)
    var templates:[Root: DOM.Template<Page.Key>], 
        roots:[Stem: Root]
    let root:
    (    
        master:URI,
        article:URI,
        sitemap:URI,
        searchIndex:URI
    )
    private 
    var redirects:[String: Index]
    
    private(set)
    var stems:Stems
    private(set)
    var caches:[Package.Index: Cache]

    private(set)
    var packages:Packages 
    
    public
    init(roots:[Root: String] = [:])
    {
        self.logo = Self.logo
        
        let master:String       = roots[.master,      default: "reference"],
            article:String      = roots[.article,     default: "learn"],
            sitemap:String      = roots[.sitemap,     default: "sitemaps"],
            searchIndex:String  = roots[.searchIndex, default: "lunr"]
        
        self.root = 
        (
            master:         .init(root: master),
            article:        .init(root: article),
            sitemap:        .init(root: sitemap),
            searchIndex:    .init(root: searchIndex)
        )
        self.redirects = [:]
        self.stems = .init()
        self.roots = 
        [
            self.stems.register(component: master):         .master,
            self.stems.register(component: article):        .article,
            self.stems.register(component: sitemap):        .sitemap,
            self.stems.register(component: searchIndex):    .searchIndex,
        ]
        
        let template:DOM.Template<Page.Key> = .init(freezing: Page.html)
        self.templates = .init(uniqueKeysWithValues: self.roots.values.map 
        { 
            ($0, template) 
        })
        
        self.packages = .init()
        self.caches = [:]
    }
}
extension Ecosystem 
{
    public mutating 
    func regenerateCaches() 
    {
        self.caches.removeAll()
        for package:Package.Index in self.packages.indices.values 
        {
            self.caches[package] = .init(
                sitemap: self.generateSiteMap(for: package),
                search: self.generateSearchIndex(for: package))
        }
    }
    
    @discardableResult
    public mutating 
    func updatePackage(_ graph:Package.Graph, pins era:[Package.ID: MaskedVersion]) 
        throws -> Package.Index
    {
        try Task.checkCancellation()
        
        let version:PreciseVersion = .init(era[graph.id])
        
        let index:Package.Index = 
            try self.packages.updatePackageRegistration(for: graph.id)
        // initialize symbol id scopes for upstream packages only
        let pins:Package.Pins ; var scopes:[Symbol.Scope] ; (pins, scopes) = 
            try self.packages.updateModuleRegistrations(in: index, 
                graphs: graph.modules, 
                version: version,
                era: era)
        let cultures:[Module.Index] = scopes.map(\.culture)
        
        let (articles, extensions):([[Article.Index: Extension]], [[String: Extension]]) = 
            self.packages[index].addExtensions(in: cultures, 
                graphs: graph.modules, 
                stems: &self.stems)
        let symbols:[[Symbol.Index: Vertex.Frame]] = 
            self.packages[index].addSymbols(through: scopes, 
                graphs: graph.modules, 
                stems: &self.stems)
        
        print("note: key table population: \(self.stems._count), total key size: \(self.stems._memoryFootprint) B")
        
        // add the newly-registered symbols to each module scope 
        for scope:Int in scopes.indices
        {
            scopes[scope].lenses.append(self[index].symbols.indices)
        }
        
        let positions:[Dictionary<Symbol.Index, Symbol.Declaration>.Keys] =
            try self.packages[index].updateDeclarations(scopes: scopes, symbols: symbols)
            try self.packages[index].updateHeadlines(for: cultures, articles: articles)
        let hints:[Symbol.Index: Symbol.Index] = 
            try self.packages.updateImplicitSymbols(in: index, 
                fromExplicit: _move(positions), 
                graphs: graph.modules, 
                scopes: scopes)
        
        let comments:[Symbol.Index: String] = 
            Self.comments(from: _move(symbols), pruning: hints)
        let documentation:Ecosystem.Documentation = 
            self.compileDocumentation(
                extensions: _move(extensions),
                articles: _move(articles),
                comments: _move(comments), 
                scopes: _move(scopes).map(\.namespaces),
                pins: pins)
        self.packages.updateDocumentation(_move(documentation), 
            hints: _move(hints), 
            pins: _move(pins))
        
        func bold(_ string:String) -> String
        {
            "\u{1B}[1m\(string)\u{1B}[0m"
        }
        
        print(bold("updated \(self[index].id) to version \(version)"))
        
        return index
    }
    
    private static
    func comments(from symbols:[[Symbol.Index: Vertex.Frame]], 
        pruning hints:[Symbol.Index: Symbol.Index]) 
        -> [Symbol.Index: String]
    {
        var comments:[Symbol.Index: String] = [:]
        for (symbol, frame):(Symbol.Index, Vertex.Frame) in symbols.joined()
            where !frame.comment.isEmpty
        {
            comments[symbol] = frame.comment
        }
        // delete comments if a hint indicates it is duplicated
        var pruned:Int = 0
        for (member, union):(Symbol.Index, Symbol.Index) in hints 
        {
            if  let comment:String  = comments[member],
                let original:String = comments[union],
                    original == comment 
            {
                comments.removeValue(forKey: member)
                pruned += 1
            }
        }
        return comments
    }
}
    
extension Ecosystem 
{
    subscript(package:Package.Index) -> Package
    {
        _read 
        {
            yield self.packages[package]
        }
    } 
    subscript(module:Module.Index) -> Module
    {
        _read 
        {
            yield self.packages[module]
        }
    } 
    subscript(symbol:Symbol.Index) -> Symbol
    {
        _read 
        {
            yield self.packages[symbol]
        }
    } 
    subscript(article:Article.Index) -> Article
    {
        _read 
        {
            yield self.packages[article]
        }
    } 
    
    @inlinable public 
    subscript(uri request:URI) -> StaticResponse?
    {
        guard case let (resolution, temporary)? = self.resolve(
            path: request.path.normalized.components, 
            query: request.query ?? [])
        else 
        {
            return nil
        }
        
        let (uri, canonical):(URI, URI?) = self.uri(of: resolution)
        
        if uri ~= request 
        {
            return self.response(for: resolution, canonical: canonical ?? uri)
        }
        else  
        {
            let uri:String = uri.description
            return temporary ? 
                .maybe(at: uri, canonical: canonical?.description ?? uri) : 
                .found(at: uri, canonical: canonical?.description ?? uri)
        }
    }

    @usableFromInline
    func uri(of resolution:Resolution) -> (exact:URI, canonical:URI?) 
    {
        switch resolution 
        {        
        case .index(let index, let pins, exhibit: let exhibit):
            return self.uri(of: index, pins: pins, exhibit: exhibit)
            
        case .choices(let choices, let pins):
            return (self.uri(of: choices, pins: pins), nil)
        
        case .searchIndex(let package): 
            return (self.uriOfSearchIndex(for: package), nil)
        
        case .sitemap(let package): 
            return (self.uriOfSiteMap(for: package), nil)
        }
    }
    private 
    func uri(of index:Index, pins:Package.Pins, exhibit:Version?) 
        -> (exact:URI, canonical:URI?) 
    {
        let pinned:Package.Pinned = .init(self[pins.local.package], 
            at: pins.local.version, 
            exhibit: exhibit)
        let uri:URI
        switch index 
        {
        case .composite(let composite):
            uri = self.uri(of: composite, in: pinned)
            guard composite.isNatural 
            else 
            {
                // if this is a synthetic feature, set the canonical page to 
                // its generic base (which may be in a completely different package)
                let canonical:URI = self.uri(of: .init(natural: composite.base), 
                    in: self[composite.base.module.package].pinned())
                return (exact: uri, canonical: canonical)
            }
        
        case .article(let article):
            uri = self.uri(of: article, in: pinned)
            
        case .module(let module):
            uri = self.uri(of: module, in: pinned)
        
        case .package(_):
            uri = self.uri(of: pinned)
        }
        
        if pinned.version == pinned.package.versions.latest 
        {
            return (exact: uri, nil)
        }
        else
        {
            // if this is an old version, set the canonical version to 
            // the latest version 
            return (exact: uri, self.uri(of: index, in: pinned.package.pinned()))
        }
    }
    private 
    func uri(of index:Index, in pinned:Package.Pinned) -> URI 
    {
        switch index 
        {
        case .composite(let composite):
            return self.uri(of: composite, in: pinned)
        case .article(let article):
            return self.uri(of: article, in: pinned)
        case .module(let module):
            return self.uri(of: module, in: pinned)
        case .package(_):
            return self.uri(of: pinned)
        }
    }

    func uri(of pinned:Package.Pinned) -> URI
    {
        self.root.master.appending(components: pinned.path)
    }
    func uri(of module:Module.Index, in pinned:Package.Pinned) -> URI
    {
        let culture:Module = pinned.package[local: module]
        if case (let uri, pinned.version)? = culture.redirect.module
        {
            return uri 
        }
        
        var uri:URI = self.root.master 
        uri.path.append(components: pinned.prefix)
        uri.path.append(component: culture.id.value)
        return uri
    }
    func uri(of article:Article.Index, in pinned:Package.Pinned) -> URI
    {
        let culture:Module = pinned.package[local: article.module]
        var uri:URI
        if case (let root, pinned.version)? = culture.redirect.articles 
        {
            uri = root 
        }
        else 
        {
            uri = self.root.article 
            uri.path.append(components: pinned.prefix)
            uri.path.append(component: culture.id.value)
        }
        for component:String in pinned.package[local: article].path
        {
            uri.path.append(component: component.lowercased())
        }
        return uri
    }
    func uri(of composite:Symbol.Composite, in pinned:Package.Pinned) -> URI
    {
        var uri:URI = self.root.master 
        
        uri.path.append(components: pinned.path(to: composite, ecosystem: self), 
            orientation: self[composite.base].orientation)
        uri.insert(parameters: pinned.query(to: composite, ecosystem: self))
        return uri
    }
    func uri(of choices:[Symbol.Composite], pins:Package.Pins) -> URI
    {
        // `first` should always exist, if not, something has gone seriously 
        // wrong in swift-biome...
        guard let exemplar:Symbol.Composite = choices.first 
        else 
        {
            fatalError("empty disambiguation group")
        }
        let pinned:Package.Pinned = .init(self[pins.local.package], 
            at: pins.local.version)
        
        var uri:URI = self.root.master 
        
        uri.path.append(components: pinned.path(to: exemplar, ecosystem: self), 
            orientation: self[exemplar.base].orientation)
        return uri
    }
    func uriOfSearchIndex(for package:Package.Index) -> URI 
    {
        self.root.searchIndex.appending(components: [self[package].name, "types"])
    }
    func uriOfSiteMap(for package:Package.Index) -> URI 
    {
        self.root.sitemap.appending(component: "\(self[package].name).txt")
    }
    
    func expand(_ link:Link) -> Link.Expansion
    {
        switch link.target 
        {
        case .package(let package): 
            return .package(package)
        case .module(let module): 
            return .module(module)
        case .article(let article): 
            return .article(article)
        case .composite(let composite):
            var trace:[Symbol.Composite] = []
                trace.reserveCapacity(link.visible)
                trace.append(composite)
            var next:Symbol.Index? = composite.host ?? self[composite.base].shape?.target
            while trace.count < link.visible
            {
                guard let current:Symbol.Index = next 
                else 
                {
                    let namespace:Module.Index = self[composite.diacritic.host].namespace
                    return .module(namespace, trace.reversed())
                }
                
                trace.append(.init(natural: current))
                next = self[current].shape?.target 
            }
            return .composite(trace.reversed())
        }
    }
}
