@_exported import PackageResolution
@_exported import SymbolGraphs
@_exported import Versions
import Resources
import DOM
import URI

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
    let whitelist:[Package.ID]
    
    private(set)
    var template:DOM.Flattened<Page.Key>
    let roots:[Route.Stem: Root]
    let root:
    (    
        master:URI,
        article:URI,
        sitemap:URI,
        searchIndex:URI
    )
    private(set)
    var redirects:[String: Redirect]
    
    private(set)
    var stems:Route.Stems
    private(set)
    var caches:[Package.Index: Cache]

    private(set)
    var packages:Packages 
    
    public
    init(roots:[Root: String] = [:], whitelist:[Package.ID] = [])
    {
        self.logo = Self.logo
        self.whitelist = whitelist
        
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
        
        self.template = .init(freezing: Page.html)
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
    
    public mutating 
    func updatePackage(_ id:Package.ID, resolved:PackageResolution,
        graphs:[SymbolGraph],
        brand:String? = nil,
        pins era:[Package.ID: MaskedVersion]) 
        throws
    {
        try Task.checkCancellation()
        // topological sort  
        let graphs:[SymbolGraph] = try graphs.topologicallySorted(for: id)
        let _:Package.Index = try self.packages._add(id, 
            resolved: resolved, 
            graphs: graphs, 
            stems: &self.stems)
    }

    @discardableResult
    public mutating 
    func updatePackage(_ id:Package.ID, 
        graphs unordered:[SymbolGraph],
        brand:String? = nil,
        pins era:[Package.ID: MaskedVersion]) 
        throws -> Package.Index
    {
        fatalError("obsoleted")
        // try Task.checkCancellation()

        // let graphs:[SymbolGraph]    = try Self.order(modules: unordered, package: id)

        // let index:Package.Index     = self.packages.addPackage(id)
        // let cultures:[Module.Index] = self.packages[index].addModules(graphs.lazy.map(\.id))

        // if let brand:String 
        // {
        //     self.packages[index].brand = brand
        // }

        // let scopes:[Module.Scope]   = try self.packages.resolveDependencies(graphs: graphs,
        //     cultures: cultures)
        
        // self.updatePackage(index, graphs: graphs, scopes: scopes, era: era)

        // return index 
    }
    private mutating 
    func updatePackage(_ index:Package.Index, 
        graphs:[SymbolGraph], 
        scopes:[Module.Scope],
        era:[Package.ID: MaskedVersion]) 
    {
        let version:PreciseVersion = .init(era[self[index].id])

        var articles:[[Article.Index: Extension]] = []
            articles.reserveCapacity(scopes.count)
        var extensions:[[String: Extension]] = []
            extensions.reserveCapacity(scopes.count)
        var abstractors:[Abstractor] = []
            abstractors.reserveCapacity(scopes.count)
        for (graph, scope):(SymbolGraph, Module.Scope) in zip(graphs, scopes)
        {
            var abstractor:Abstractor = graph.abstractor(context: self.packages, scope: scope)
                self.packages[index].addSymbols(from: graph,
                    abstractor: &abstractor,
                    stems: &self.stems,
                    scope: scope)
            abstractors.append(abstractor)

            let column:(articles:[Article.Index: Extension], extensions:[String: Extension]) =
                self.packages[index].addExtensions(from: graph, 
                    stems: &self.stems, 
                    culture: scope.culture)
            extensions.append(column.extensions)
            articles.append(column.articles)
        }
        
        print("""
            note: key table population: \(self.stems._count), \
            total key size: \(self.stems._memoryFootprint) B
            """)
        // must call this *before* any other update methods 
        let pins:Package.Pins = self.packages.updatePackageVersion(for: index, 
            version: version, 
            scopes: scopes, 
            era: era)
        
        var beliefs:Beliefs = graphs.generateBeliefs(abstractors: abstractors, 
            context: self.packages)
        let trees:Route.Trees = beliefs.generateTrees(
            context: self.packages)
        self.packages[index].addNaturalRoutes(trees.natural)
        self.packages[index].addSyntheticRoutes(trees.synthetic)

        // write to the keyframe buffers
        self.packages[index].pushBeliefs(&beliefs, stems: self.stems)
        for scope:Module.Scope in scopes
        {
            self.packages[index].pushDependencies(scope.dependencies(), culture: scope.culture)
        }
        for (scope, articles):(Module.Scope, [Article.Index: Extension]) in zip(scopes, articles)
        {
            self.packages[index].pushExtensionMetadata(articles: articles, culture: scope.culture)
        }
        for (graph, abstractor):(SymbolGraph, Abstractor) in zip(graphs, abstractors)
        {
            self.packages[index].pushDeclarations(graph.declarations(abstractor: abstractor))
            self.packages[index].pushToplevel(filtering: abstractor.updates)
        }

        self.packages.spread(from: index, beliefs: beliefs)

        let compiled:[Index: DocumentationNode] = self.compile(
            comments: graphs.generateComments(abstractors: abstractors),
            extensions: extensions,
            articles: articles,
            scopes: scopes,
            pins: pins)
        
        self.packages[index].pushDocumentation(compiled)
        
        func bold(_ string:String) -> String
        {
            "\u{1B}[1m\(string)\u{1B}[0m"
        }
        
        print(bold("updated \(self[index].id) to version \(version)"))
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
    
    public 
    func index(of module:Module.ID, in package:Package.Index) -> Module.Index?
    {
        self[package].modules.indices[module]
    }
    
    public mutating 
    func move(_ resource:Resource, to uri:URI)
    {
        self.redirects[uri.description] = .resource(resource)
    }
    public mutating 
    func move(module:Module.Index, to uri:URI, template:DOM.Flattened<Page.Key>? = nil)
    {
        let pins:Package.Pins = 
            self.packages[module.package].move(module: module, to: uri)
        self.redirects[uri.description] = .index(.module(module), pins: pins, 
            template: template)
    }
    public mutating 
    func move(articles module:Module.Index, to uri:URI, template:DOM.Flattened<Page.Key>? = nil)
    {
        fatalError("unimplemented")
        // let pins:Package.Pins = 
        //     self.packages[module.package].move(articles: module, to: uri)
        // for article:Article.Index in self[module].articles.joined()
        // {
        //     var uri:URI = uri 
        //     for component:String in self[article].path 
        //     {
        //         uri.path.append(component: component.lowercased())
        //     }
        //     self.redirects[uri.description] = .index(.article(article), pins: pins, 
        //         template: template)
        // }
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
