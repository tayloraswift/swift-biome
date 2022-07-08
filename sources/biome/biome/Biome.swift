import HTML
import Resource

public
struct Biome 
{
    let template:DOM.Template<Page.Key, [UInt8]>, 
        logo:[UInt8]
    @usableFromInline private(set)
    var ecosystem:Ecosystem
    private(set)
    var stems:Stems
    private 
    let root:
    (
        master:Stem, 
        article:Stem,
        sitemap:Stem,
        searchIndex:Stem
    )
    private 
    var sitemaps:SiteMapCache, 
        searchIndices:SearchIndexCache
    
    public 
    init(roots:[Root: String] = [:], template:DOM.Template<Page.Key, [UInt8]>) 
    {
        self.ecosystem = .init(roots: roots)
        self.searchIndices = .init()
        self.sitemaps = .init()
        self.stems = .init()
        
        let logo:HTML.Element<Never> = .ol(items: [.li(.a(
        [
            .text(escaped: "swift"), 
            .container(.i, content: [.text(escaped: "init")])
        ]) 
        { 
            ("class", "logo") 
            ("href", "/")
        })])
        
        self.logo = logo.rendered(as: [UInt8].self)
        self.template = template 
        
        self.root = 
        (
            master:         self.stems.register(component: self.ecosystem.root.master),
            article:        self.stems.register(component: self.ecosystem.root.article),
            sitemap:        self.stems.register(component: self.ecosystem.root.sitemap),
            searchIndex:    self.stems.register(component: self.ecosystem.root.searchIndex)
        )
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
        
        let (uri, canonical):(URI, URI?) = self.ecosystem.uri(of: resolution)
        
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
    func resolve(path:[String], query:[URI.Parameter]) 
        -> (resolution:Ecosystem.Resolution, redirected:Bool)?
    {
        guard let first:String = path.first
        else 
        {
            return nil
        }
        let root:Root 
        switch self.stems[leaf: first]
        {
        case self.root.master?:         root = .master
        case self.root.article?:        root = .article
        case self.root.sitemap?:        root = .sitemap
        case self.root.searchIndex?:    root = .searchIndex
        default:
            return nil 
        }
        return self.ecosystem.resolve(path.dropFirst(), 
            root: root, query: query, stems: self.stems) 
    }
    @usableFromInline 
    func response(for resolution:Ecosystem.Resolution, canonical uri:URI) -> StaticResponse 
    {
        switch resolution 
        {
        case .index(let index, pins: let pins, exhibit: let exhibit): 
            var page:Page = .init(self.ecosystem.pinned(pins), logo: self.logo)
                page.generate(for: index, exhibit: exhibit)
            return .matched(.utf8(encoded: self.template.rendered(as: [UInt8].self, 
                    substituting: _move(page).substitutions), 
                    type: .html, 
                    tag: nil), 
                canonical: uri.description)
        
        case .choices(let choices, pins: let pins): 
            var page:Page = .init(self.ecosystem.pinned(pins), logo: self.logo)
                page.generate(for: choices, uri: uri)
            return .multiple(.utf8(encoded: self.template.rendered(as: [UInt8].self, 
                    substituting: _move(page).substitutions), 
                    type: .html, 
                    tag: nil))
        
        case .searchIndex(let package): 
            guard let cached:Resource = self.searchIndices[package]
            else 
            {
                return .error(.text("search index for '\(self.ecosystem[package].id)' not available"))
            }
            return .matched(cached, canonical: uri.description) 
        
        case .sitemap(let package): 
            guard let cached:Resource = self.sitemaps[package]
            else 
            {
                return .error(.text("sitemap for '\(self.ecosystem[package].id)' not available"))
            }
            return .matched(cached, canonical: uri.description) 
        }
    }
    
    public mutating 
    func regenerateCaches() 
    {
        self.searchIndices.regenerate(from: self.ecosystem)
        self.sitemaps.regenerate(from: self.ecosystem)
    }
    public mutating 
    func updatePackage(_ graph:Package.Graph, era:[Package.ID: MaskedVersion]) throws 
    {
        try Task.checkCancellation()
        
        let version:PreciseVersion = .init(era[graph.id])
        
        let index:Package.Index = 
            try self.ecosystem.updatePackageRegistration(for: graph.id)
        // initialize symbol id scopes for upstream packages only
        let pins:Package.Pins<Version> ; var scopes:[Symbol.Scope] ; (pins, scopes) = 
            try self.ecosystem.updateModuleRegistrations(in: index, 
                graphs: graph.modules, 
                version: version,
                era: era)
        
        let (articles, extensions):([[Article.Index: Extension]], [[String: Extension]]) = 
            self.ecosystem[index].addExtensions(in: scopes.map(\.culture), 
                graphs: graph.modules, 
                stems: &self.stems)
        let symbols:[[Symbol.Index: Vertex.Frame]] = 
            self.ecosystem[index].addSymbols(through: scopes, 
                graphs: graph.modules, 
                stems: &self.stems)
        
        print("note: key table population: \(self.stems._count), total key size: \(self.stems._memoryFootprint) B")
        
        // add the newly-registered symbols to each module scope 
        for scope:Int in scopes.indices
        {
            scopes[scope].lenses.append(self.ecosystem[index].symbols.indices)
        }
        
        let positions:[Dictionary<Symbol.Index, Symbol.Declaration>.Keys] =
            try self.ecosystem[index].updateDeclarations(scopes: scopes, symbols: symbols)
        let hints:[Symbol.Index: Symbol.Index] = 
            try self.ecosystem.updateImplicitSymbols(in: index, 
                fromExplicit: _move(positions), 
                graphs: graph.modules, 
                scopes: scopes)
        
        let comments:[Symbol.Index: String] = 
            Self.comments(from: _move(symbols), pruning: hints)
        let documentation:Ecosystem.Documentation = 
            self.ecosystem.compileDocumentation(for: index, 
                extensions: _move(extensions),
                articles: _move(articles),
                comments: _move(comments), 
                scopes: _move(scopes).map(\.namespaces),
                stems: self.stems,
                pins: pins)
        self.ecosystem.updateDocumentation(in: index, 
            upstream: _move(pins).upstream,
            compiled: _move(documentation), 
            hints: _move(hints))
        
        func bold(_ string:String) -> String
        {
            "\u{1B}[1m\(string)\u{1B}[0m"
        }
        
        print(bold("updated \(self.ecosystem[index].id) to version \(version)"))
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
