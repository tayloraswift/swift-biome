import HTML
import Resource

extension URI 
{
    public 
    enum Prefix:Hashable, Sendable 
    {
        case master
        case doc
        case lunr
    }
}
public
struct Biome 
{
    let template:DOM.Template<Page.Key, [UInt8]>, 
        logo:[UInt8]
    private(set)
    var ecosystem:Ecosystem
    private(set)
    var stems:Stems
    private 
    let stem:
    (
        master:Stem, 
        doc:Stem,
        lunr:Stem
    )
    private 
    var search:SearchIndexCache
    
    public 
    init(prefixes:[URI.Prefix: String] = [:], template:DOM.Template<Page.Key, [UInt8]>) 
    {
        self.ecosystem = .init(prefixes: prefixes)
        self.search = .init()
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
        
        self.stem = 
        (
            master:     self.stems.register(component: self.ecosystem.prefix.master),
            doc:        self.stems.register(component: self.ecosystem.prefix.doc),
            lunr:       self.stems.register(component: self.ecosystem.prefix.lunr)
        )
    }
    
    public 
    subscript(request:String, referrer referrer:Never?) -> StaticResponse?
    {
        guard let request:URI = try? .init(absolute: request)
        else 
        {
            return nil 
        }
        guard case let (resolution, temporary)? = self.resolve(uri: request)
        else 
        {
            return nil
        }
        
        let uri:URI = self.ecosystem.uri(of: resolution)
        if  uri ~= request 
        {
            return self.response(for: uri, resolution: resolution)
        }
        else  
        {
            let uri:String = uri.description
            return temporary ? 
                .maybe(at: uri, canonical: uri) : 
                .found(at: uri, canonical: uri)
        }
    }
    private 
    func resolve(uri:URI) -> (resolution:Ecosystem.Resolution, redirected:Bool)?
    {
        let path:[String] = uri.path.normalized.components
        guard let first:String = path.first
        else 
        {
            return nil
        }
        let prefix:URI.Prefix 
        switch self.stems[leaf: first]
        {
        case self.stem.master?: prefix = .master
        case self.stem.doc?:    prefix = .doc
        case self.stem.lunr?:   prefix = .lunr 
        default:
            return nil 
        }
        return self.ecosystem.resolve(path.dropFirst(), 
            prefix: prefix, 
            query: uri.query ?? [], 
            stems: self.stems) 
    }
    private 
    func response(for uri:URI, resolution:Ecosystem.Resolution) -> StaticResponse 
    {
        switch resolution 
        {
        case .selection(let selection, pins: let pins): 
            var page:Page = .init(self.ecosystem.pinned(pins), logo: self.logo)
            switch selection 
            {
            case .composites(let choices):
                page.generate(for: choices)
                return .multiple(.utf8(encoded: self.template.rendered(as: [UInt8].self, 
                        substituting: _move(page).substitutions), 
                        type: .html, 
                        tag: nil))
            
            case .index(let index):
                page.generate(for: index)
                return .matched(.utf8(encoded: self.template.rendered(as: [UInt8].self, 
                        substituting: _move(page).substitutions), 
                        type: .html, 
                        tag: nil), 
                    canonical: uri.description)
            }
        
        case .searchIndex(let package): 
            guard let cached:Resource = self.search.indices[package]
            else 
            {
                return .error(.text("search index cache for '\(self.ecosystem[package].id)' not available"))
            }
            return .matched(cached, canonical: uri.description) 
        }
    }
    public mutating 
    func regenerateSearchIndexCache() 
    {
        self.search.regenerate(from: self.ecosystem)
    }
    public mutating 
    func updatePackage(_ graph:Package.Graph, era:[Package.ID: MaskedVersion]) throws 
    {
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
