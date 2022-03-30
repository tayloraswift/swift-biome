import StructuredDocument
import Resource
import JSON

public 
struct Documentation:Sendable
{
    enum Index:Hashable, Sendable 
    {
        case article(Int)
        
        case packageSearchIndex(Int)
        case package(Int)
        case module(Int)
        case symbol(Int, victim:Int?)
        
        case ambiguous
    }
    
    let biome:Biome 
    let routing:RoutingTable
    
    let template:DocumentTemplate<Anchor, [UInt8]>
    private(set)
    var articles:[Expatriate<Article<ResolvedLink>>]
    private(set)
    var modules:[Article<ResolvedLink>.Content], 
        symbols:[Article<ResolvedLink>.Content] 
    
    private(set)
    var search:[Resource] 
    
    public 
    init<Location>(serving bases:[URI.Base: String], 
        template:DocumentTemplate<Anchor, [UInt8]>,
        loading catalogs:[Catalog<Location>], 
        with load:(_ location:Location, _ type:Resource.Text) async throws -> Resource) 
        async throws 
    {
        let (biome, comments):(Biome, [String]) = try await Biome.load(catalogs: catalogs, with: load)
        // this needs to be mutable, because we don’t know if articles are free 
        // or owned until after we’ve built the initial routing table from the biome 
        // (which is a `let`). the uri of an article depends on whether it has 
        // an owner, so we need to register the free articles in a second pass.
        var routing:RoutingTable = .init(bases: bases, biome: biome)
        Swift.print("initialized routing table")
        
        var symbols:[Int: (content:Article<UnresolvedLink>.Content, context:UnresolvedLinkContext)] = [:]
        var modules:[Int: (content:Article<UnresolvedLink>.Content, context:UnresolvedLinkContext)] = [:]
        
        Swift.print("starting article loading")
        var articles:[Expatriate<Article<UnresolvedLink>>] = []
        for (package, catalog):(Biome.Package, Catalog<Location>) in zip(biome.packages, catalogs)
        {
            for entry:Catalog<Location>.Article in catalog.articles 
            {
                // for now, we require every article path to begin with a module name
                guard   let module:Biome.Module.ID = entry.path.first.map(Biome.Module.ID.init(_:)), 
                        let module:Int = routing.trunks[module.trunk], package.modules ~= module 
                else 
                {
                    fatalError("unimplemented")
                }
                let source:String 
                // TODO: handle versioning
                switch try await load(entry.location, .markdown)
                {
                case    .text   (let text,  type: _, version: _):
                    source = text
                case    .binary (let bytes, type: _, version: _):
                    source = String.init(decoding: bytes, as: Unicode.UTF8.self)
                }
                
                // default to DocC mode for now
                let surveyed:Surveyed = .init(markdown: source, format: .docc)
                if let master:UnresolvedLink = surveyed.master
                {
                    // TODO: handle this error
                    switch try routing.resolve(base: .biome, link: master, context: 
                        routing.context(imports: surveyed.metadata.imports, 
                            greenzone: (module, [])))
                    {
                    case .article: 
                        // biome base never hosts articles
                        fatalError("unreachable")
                    
                    case .module(let namespace):
                        modules[namespace] = surveyed.rendered(biome: biome, routing: routing, 
                            greenzone: (namespace, []))
                    
                    case .symbol(let witness, victim: nil, components: _):
                        // guard let reassignment:Int = biome.symbols[witness].namespace
                        // else 
                        // {
                        //     fatalError("cannot override documentation for mythical symbols")
                        // }
                        symbols[witness] = surveyed.rendered(biome: biome, routing: routing, 
                            greenzone: biome.greenzone(witness: witness, victim: nil))
                    
                    case .symbol(_, victim: _?, components: _):
                        fatalError("UNIMPLEMENTED")
                    }
                }
                else if case .explicit(let heading) = surveyed.headline 
                {
                    let context:UnresolvedLinkContext
                    var content:Article<UnresolvedLink>.Content
                    
                    (content, context) = surveyed.rendered(biome: biome, routing: routing, greenzone: (module, []))
                    
                    let headline:Element? = surveyed.headline.rendered()
                    let article:Article<UnresolvedLink> = .init(title: heading.plainText, 
                        path: surveyed.metadata.path.isEmpty ? entry.path : surveyed.metadata.path, 
                        snippet: surveyed.snippet,
                        headline: headline, 
                        content: content)
                    let expatriate:Expatriate<Article<UnresolvedLink>> = .init(conquistador: article, 
                        marque: .init(trunk: module, whitelist: context.whitelist))
                    routing.publish(expatriate: expatriate, under: .article(articles.endIndex))
                    articles.append(expatriate)
                }
                else 
                {
                    fatalError("articles require a title")
                }
            }
        }
        // everything that will ever be registered has been registered at this point
        self.articles = articles.map 
        { 
            $0.map 
            {
                .init(title: $0.title, path: $0.path, snippet: $0.snippet, headline: $0.headline, 
                    content: routing.resolve(article: $0.content, context: $1))
            }
        }
        Swift.print("finished article loading")
        // the only way modules can get documentation is by owning an article
        self.modules = biome.modules.indices.map 
        {
            (module:Int) in modules.removeValue(forKey: module).map
            {
                routing.resolve(article: $0.content, context: $0.context)
            } ?? .empty
        }
        self.symbols = zip(biome.symbols.indices, _move(comments)).map 
        {
            (symbol:(index:Int, comment:String)) in 
            
            let comment:String?
            if case nil = biome.symbols[symbol.index].sponsor, !symbol.comment.isEmpty
            {
                comment = symbol.comment
            }
            else 
            {
                // don’t re-render duplicated docs 
                comment = nil
            }
            
            switch (comment, symbols.removeValue(forKey: symbol.index))
            {
            // FIXME: handle conflicting doccomments and articles 
            case (_, let overriding?):
                return routing.resolve(article: overriding.content, context: overriding.context)
            case (let string?, nil):
                let surveyed:Surveyed = .init(markdown: string, format: .docc)
                guard case .implicit = surveyed.headline 
                else 
                {
                    fatalError("documentation comment cannot begin with an `h1`")
                }
                let (content, context):(Article<UnresolvedLink>.Content, UnresolvedLinkContext) = 
                    surveyed.rendered(biome: biome, routing: routing, 
                        greenzone: biome.greenzone(witness: symbol.index, victim: nil))
                return routing.resolve(article: content, context: context)
            case (nil, nil): 
                // undocumented 
                break 
            }
            
            return .empty
        }
        
        self.template   = template
        self.search     = biome.searchIndices(routing: routing)
        self.routing    = routing
        self.biome      = _move(biome)
    }
    public 
    func sitemap(for package:Biome.Package.ID) -> (uris:[String], hash:Resource.Version?)
    {
        guard let index:Int = self.biome.packages.index(of: package)
        else 
        {
            fatalError("unknown package '\(package)'")
        }
        let package:Biome.Package = self.biome.packages[index]
        
        var sitemap:[String] = []
        for index:Int in self.articles.indices where package.modules ~= self.articles[index].trunk
        {
            sitemap.append(self.format(uri: self.uri(article: index)))
        }
        
        sitemap.append(self.format(uri: self.uri(package: index)))
        for index:Int in package.modules
        {
            sitemap.append(self.format(uri: self.uri(module: index)))
            
            for index:Int in self.biome.modules[index].allSymbols
            {
                sitemap.append(self.format(uri: self.uri(witness: index, victim: nil)))
                for member:Int in self.biome.symbols[index].relationships.members ?? []
                {
                    if  let interface:Int = self.biome.symbols[member].parent, 
                            interface != index 
                    {
                        sitemap.append(self.format(uri: self.uri(witness: member, victim: index)))
                    }
                }
            } 
        }
        
        return (sitemap, package.hash)
    }

    public 
    subscript(uri:String, referrer _:String? = nil) -> StaticResponse?
    {
        let response:(payload:Resource, location:URI)?,
            redirect:(always:Bool, temporarily:Bool), 
            normalized:URI 
        
        (normalized, redirect.always) = self.normalize(uri: uri)
        
        if  case .biome             = normalized.base, 
            let query:URI.Query     = normalized.query, 
            let victim:Int          = query.victim, 
            let index:Index         = self.routing.resolve(overload: query.witness, self: victim)
        {
            response                = self[index]
            redirect.temporarily    = false 
        }
        else if let (index, assigned):(Index, assigned:Bool) = 
            self.routing.resolve(
                base: normalized.base, 
                path: normalized.path, 
                overload: normalized.query?.witness)
        {
            response                = self[index]
            redirect.temporarily    = !assigned
        }
        else if case .biome         = normalized.base, 
                let witness:Int     = normalized.query?.witness,
                let index:Index     = self.routing.resolve(mythical: witness)
        {
            response                = self[index]
            redirect.temporarily    = false
        }
        else 
        {
            return nil
        }
        guard let response:(payload:Resource, location:URI) = response 
        else 
        {
            //return .none(self.notFound)
            return nil
        }
        
        let location:String     = self.format(uri: response.location)
        // TODO: fixme
        let canonical:String    = location 
        
        switch (matches: response.location == normalized, redirect: redirect) 
        {
        case    (matches:  true, redirect: (always: false, temporarily: _)):
            // ignore temporary-redirect flag, since temporary redirects should never match 
            return .matched(canonical: canonical, response.payload)
        case    (matches:  true, redirect: (always:  true, temporarily: _)),
                (matches: false, redirect: (always:     _, temporarily: false)):
            return   .found(canonical: canonical, at: location)
        case    (matches: false, redirect: (always:     _, temporarily:  true)):
            return   .maybe(canonical: canonical, at: location)
        }
    }
    
    // TODO: implement disambiguation pages so this can become non-optional
    subscript(index:Index) -> (payload:Resource, location:URI)?
    {
        var _filter:[Biome.Package.ID] 
        {
            self.biome.packages.map(\.id)
        }
        let location:URI, 
            resource:Resource 
        switch index
        {
        case .ambiguous: 
            return nil
        
        case .article(let index):
            let substitutions:[Anchor: Element] = 
                self.substitutions(article: index, filter: _filter)
            location =    self.uri(article: index)
            resource = .html(utf8: self.template.apply(substitutions).joined(), version: nil)
        
        case .packageSearchIndex(let index):
            location = self.uri(packageSearchIndex: index)
            resource = self.search[index]
        
        case .package(let index):
            let substitutions:[Anchor: Element] = 
                self.substitutions(package: index, filter: _filter)
            location =    self.uri(package: index)
            resource = .html(utf8: self.template.apply(substitutions).joined(), version: nil)
        
        case .module(let index):
            let substitutions:[Anchor: Element] = 
                self.substitutions(module: index, filter: _filter)
            location =    self.uri(module: index)
            resource = .html(utf8: self.template.apply(substitutions).joined(), version: nil)
        
        case .symbol(let index, victim: let victim):
            let substitutions:[Anchor: Element] = 
                self.substitutions(witness: index, victim: victim, filter: _filter)
            location =    self.uri(witness: index, victim: victim)
            resource = .html(utf8: self.template.apply(substitutions).joined(), version: nil)
        }
        return (resource, location)
    }
    


    /// the `group` is the full URL path, without the query, and including 
    /// the beginning slash '/' and path prefix. 
    /// the path *must* be normalized with respect to slashes, but it 
    /// *must not* be percent-decoded. (otherwise the user may be sent into 
    /// an infinite redirect loop.)
    ///
    /// '/reference/swift-package/somemodule/foo/bar.baz%28_%3A%29':    OK (canonical page for `SomeModule.Foo.Bar.baz(_:)`)
    /// '/reference/swift-package/somemodule/foo/bar.baz(_:)':          OK (301 redirect to `SomeModule.Foo.Bar.baz(_:)`)
    /// '/reference/swift-package/SomeModule/FOO/BAR.BAZ(_:)':          OK (301 redirect to `SomeModule.Foo.Bar.baz(_:)`)
    /// '/reference/swift-package/somemodule/foo/bar%2Ebaz%28_%3A%29':  OK (301 redirect to `SomeModule.Foo.Bar.baz(_:)`)
    /// '/reference/swift-package/somemodule/foo//bar.baz%28_%3A%29':   Error (slashes not normalized)
    ///
    /// note: the URL of a page for an operator containing a slash '/' *must*
    /// be percent-encoded; Biome will not be able to redirect it to the 
    /// correct canonical URL. 
    ///
    /// note: the URL path is case-insensitive, but the disambiguation query 
    /// *is* case-sensitive. the `disambiguation` parameter should include 
    /// the mangled name only, without the `?overload=` part. if you provide 
    /// a valid disambiguation query, the URL path can be complete garbage; 
    /// Biome will respond with a 301 redirect to the correct page.
}
