import DOM
import HTML
import PackageResolution
import Resources
import SymbolGraphs
import SymbolSource
import Versions
import WebSemantics
import URI

public typealias Ecosystem = Service 

public 
struct Service 
{
    // struct Exception:Error, CustomStringConvertible 
    // {
    //     let description:String 

    //     init(_ message:String = "", 
    //         function:String = #function, 
    //         file:String = #file, 
    //         line:Int = #line)
    //     {
    //         self.description = 
    //         """
    //         exception: \(message)
    //         {
    //             function: \(function)
    //             location: \(file):\(line)
    //         }
    //         """
    //     }
    // }

    private(set) 
    var functions:Functions
    // private 
    var packages:Packages, 
        stems:Route.Stems
    
    //private
    var template:DOM.Flattened<PageElement>

    let logo:[UInt8]

    public 
    init() 
    {
        self.functions = .init([:])
        self.packages = .init()
        self.stems = .init()

        self.template = .init(freezing: .defaultPageTemplate)

        let logo:HTML.Element<Never> = .ol(.li(.a(
                .init(escaped: "swift"), 
                .i(.init(escaped: "init")), 
            attributes: [.class("logo"), .href("/")])))
        self.logo = logo.node.rendered(as: [UInt8].self)
    }
}
extension Service 
{
    public mutating 
    func enable(function namespace:ModuleIdentifier, 
        nationality:Packages.Index, 
        template:DOM.Flattened<PageElement>? = nil) -> Bool 
    {
        if  let position:Atom<Module>.Position = 
                self.packages[nationality].latest()?.modules.find(namespace),
                self.functions.create(namespace, 
                    nationality: nationality, 
                    template: template ?? self.template)
        {
            self.packages[nationality].tree[local: position].isFunction = true
            return true 
        }
        else 
        {
            return false 
        }
    }

    @discardableResult
    public mutating 
    func updatePackage(_ id:PackageIdentifier, 
        resolved:PackageResolution,
        branch:String, 
        fork:String? = nil,
        date:Date, 
        tag:String? = nil,
        graphs:[SymbolGraph]) throws -> Packages.Index
    {
        try Task.checkCancellation()
        guard let branch:Tag = .init(parsing: branch) 
        else 
        {
            fatalError("branch name cannot be empty")
        }
        let fork:Version.Selector? = fork.flatMap(Version.Selector.init(parsing:))
        let tag:Tag? = tag.flatMap(Tag.init(parsing:))
        // topological sort  
        let graphs:[SymbolGraph] = try graphs.topologicallySorted(for: id)
        return try self.packages._add(package: id, 
            resolved: resolved, 
            branch: branch, 
            fork: fork,
            date: date,
            tag: tag,
            graphs: graphs, 
            stems: &self.stems)
    }
}

extension Service 
{
    private 
    func response(for request:__owned GetRequest, template:DOM.Flattened<PageElement>) 
        throws -> WebSemantics.Response<Resource>
    {
        let uri:String = request.uri.description
        switch request.query
        {
        case .redirect(canonical: let canonical):
            return .init(uri: uri, canonical: canonical?.description ?? uri, 
                redirection: .permanent)
        
        case .migration(_): 
            fatalError("unimplemented")
        
        case .selection(let query): 
            return .init(uri: uri, results: .many, 
                payload: try self.response(for: query, template: template, uri: request.uri))
        
        case .documentation(let query): 
            return .init(uri: uri, canonical: query.canonical?.description ?? uri, 
                payload: try self.response(for: query, template: template))
        }
    }
    private 
    func response(for query:DisambiguationQuery, template:DOM.Flattened<PageElement>, uri:URI) 
        throws -> Resource
    {
        let searchable:[String] = self._searchable()
        var cache:ReferenceCache = .init(functions: self.functions.names) 

        let context:LocalContext = .init(local: query.nationality,
            version: query.version,
            context: self.packages)
        let page:DisambiguationPage = try .init(query.choices, logo: self.logo, uri: uri, 
            searchable: _move searchable, 
            context: context, 
            cache: &cache)
        return .init(hashing: template.rendered(page.render(element:)), 
            type: .utf8(encoded: .html))
    }
    private 
    func response(for query:DocumentationQuery, template:DOM.Flattened<PageElement>) 
        throws -> Resource
    {
        let searchable:[String] = self._searchable()
        var cache:ReferenceCache = .init(functions: self.functions.names) 
        let utf8:[UInt8]
        switch query.target 
        {
        case .package(let nationality): 
            let context:BidirectionalContext = .init(local: nationality,
                version: query.version,
                context: self.packages)
            let page:PackagePage = try .init(logo: logo, 
                //documentation: query._objects,
                searchable: _move searchable,
                evolution: .init(local: context.local, functions: cache.functions), 
                context: context,
                cache: &cache)
            utf8 = template.rendered(page.render(element:))
        
        case .module(let module): 
            let context:BidirectionalContext = .init(local: module.nationality,
                version: query.version,
                context: self.packages)
            let page:ModulePage = try .init(module, logo: logo, 
                documentation: query._objects,
                searchable: _move searchable,
                evolution: .init(for: module, local: context.local, 
                    functions: cache.functions), 
                context: context,
                cache: &cache)
            utf8 = template.rendered(page.render(element:))
        
        case .article(let article): 
            let context:BidirectionalContext = .init(local: article.nationality,
                version: query.version,
                context: self.packages)
            let page:ArticlePage = try .init(article, logo: logo, 
                documentation: query._objects,
                searchable: _move searchable,
                evolution: .init(for: article, local: context.local, 
                    functions: cache.functions), 
                context: context,
                cache: &cache)
            utf8 = template.rendered(page.render(element:))
        
        case .symbol(let atomic):
            let context:BidirectionalContext = .init(local: atomic.nationality,
                version: query.version,
                context: self.packages)
            let page:SymbolPage = try .init(atomic, 
                documentation: query._objects, 
                searchable: _move searchable,
                evolution: .init(for: atomic, local: context.local,
                    context: self.packages, 
                    functions: cache.functions), 
                context: context,
                cache: &cache)
            utf8 = template.rendered(page.render(element:))
        
        case .compound(let compound):
            let context:BidirectionalContext = .init(local: compound.nationality,
                version: query.version,  
                context: self.packages)
            let page:SymbolPage = try .init(compound, 
                documentation: query._objects, 
                searchable: _move searchable,
                evolution: .init(for: compound, local: context.local,
                    context: self.packages, 
                    functions: cache.functions), 
                context: context,
                cache: &cache)
            utf8 = template.rendered(page.render(element:))
        }
        return .init(hashing: _move utf8, type: .utf8(encoded: .html))
    }
    private 
    func _searchable() -> [String] 
    {
        self.packages.map 
        {
            Address.init(.init(nil, residency: $0.id, version: nil), function: .lunr)
                .uri(functions: self.functions.names)
                .description
        }
    }
}
extension Service 
{
    func get(_ uri:URI) -> WebSemantics.Response<Resource>
    {
        do 
        {
            var link:GlobalLink = .init(uri)
            if  let first:String = link.descend(), 
                let function:Function = self.functions[first]
            {
                switch function 
                {
                case .public(.sitemap):
                    break
                
                case .public(.lunr):
                    break
                
                case .public(.documentation(let scheme)):
                    if let request:GetRequest = self.get(uri, scheme: scheme, link: _move link)
                    {
                        return try self.response(for: _move request, template: self.template)
                    }
                
                case .custom(let custom): 
                    if let request:GetRequest = self.get(uri, function: custom, link: _move link)
                    {
                        return try self.response(for: _move request, template: custom.template)
                    }
                }
            }
            return .init(uri: uri.description, results: .none, 
                payload: .init("page not found.")) 
        }
        catch let error
        {
            return .init(uri: uri.description, results: .error, 
                payload: .init("\(error)")) 
        }
    }
}
extension Service 
{
    func get(_ request:URI, function:CustomFunction, link:__owned GlobalLink) -> GetRequest? 
    {
        guard let residency:Package.Pinned = self.packages[function.nationality].latest()
        else 
        {
            return nil 
        }
        guard let namespace:Atom<Module>.Position = residency.modules.find(function.namespace)
        else 
        {
            return nil 
        }
        if  let key:_SymbolLink = try? .init(_move link), 
            let key:Route = self.stems[namespace.atom, straight: key], 
            let article:Atom<Article>.Position = residency.articles.find(.init(key))
        {
            return .init(request, residency: residency, namespace: namespace, article: article, 
                functions: self.functions.names)
        }
        else 
        {
            return .init(request, residency: residency, namespace: namespace, 
                functions: self.functions.names)
        }
    }
}
extension Service 
{
    func get(_ request:URI, scheme:Scheme, link:__owned GlobalLink) -> GetRequest?
    {
        var link:GlobalLink = _move link
        if  let residency:Package = link.descend(where: { self.packages[.init($0)] }) 
        {
            return self.get(request, scheme: scheme, explicit: _move residency, 
                link: _move link)
        }
        return  
            self.get(request, scheme: scheme, implicit: self.packages.swift, link: link) ?? 
            self.get(request, scheme: scheme, implicit: self.packages.core,  link: link)
    }
    private 
    func get(_ request:URI, scheme:Scheme, explicit:__owned Package, link:__owned GlobalLink) 
        -> GetRequest?
    {
        try? self.get(request, scheme: scheme, residency: _move explicit, link: link)
    }
    private 
    func get(_ request:URI, scheme:Scheme, implicit:__owned Package, link:__owned GlobalLink) 
        -> GetRequest?
    {
        guard   let request:GetRequest = try? self.get(request, scheme: scheme, 
                    residency: _move implicit, 
                    link: link)
        else 
        {
            return nil 
        }
        if  case .documentation(let query) = request.query, 
            case .package = query.target 
        {
            return nil 
        }
        else 
        {
            return request
        }
    }
    private 
    func get(_ request:URI, scheme:Scheme, residency:__owned Package, link:__owned GlobalLink) 
        throws -> GetRequest?
    {
        var link:GlobalLink = link
        let arrival:Version? = link.descend 
        {
            Version.Selector.init(parsing: $0).flatMap(residency.tree.find(_:))
        } 
        guard let arrival:Version = arrival ?? residency.tree.default 
        else 
        {
            return nil 
        }

        let residency:Package.Pinned = .init(_move residency, version: _move arrival)
        // we must parse the symbol link *now*, otherwise references to things 
        // like global vars (`Swift.min(_:_:)`) won’t work
        guard let link:_SymbolLink = try .init(link)
        else 
        {
            return .init(request, residency: residency, functions: self.functions.names)
        }
        //  we can store a module id in a ``Symbol/Link``, because every 
        //  ``Module/ID`` is a valid ``Symbol/Link/Component``.
        guard let namespace:Atom<Module>.Position = residency.modules.find(.init(link.first))
        else 
        {
            return nil
        }
        guard let link:_SymbolLink = link.suffix 
        else 
        {
            return .init(request, residency: residency, namespace: namespace, 
                functions: self.functions.names)
        }
        // doc scheme never uses nationality query parameter 
        if      case .doc = scheme, 
                let key:Route = self.stems[namespace.atom, straight: link], 
                let article:Atom<Article>.Position = residency.articles.find(.init(key))
        {
            return .init(request, residency: residency, namespace: namespace, article: article, 
                functions: self.functions.names)
        }
        else if let nationality:_SymbolLink.Nationality = link.nationality,
                let package:Package = self.packages[nationality.id],
                let version:Version = 
                    nationality.version.map(package.tree.find(_:)) ?? package.tree.default,
                let endpoint:GetRequest = self.get(request, scheme: scheme, 
                    nationality: .init(_move package, version: version), 
                    namespace: namespace.atom, 
                    link: link.disambiguated()) 
        {
            return endpoint
        }
        return self.get(request, scheme: scheme, 
            nationality: _move residency, 
            namespace: namespace.atom, 
            link: link.disambiguated())
    }
}
extension Service 
{
    private 
    func get(_ request:URI, scheme:Scheme, 
        nationality:__owned Package.Pinned, 
        namespace:Atom<Module>,
        link:__owned _SymbolLink) -> GetRequest?
    {
        guard let key:Route = self.stems[namespace, link]
        else 
        {
            return nil 
        }

        // first class: select symbols that exist in the requested version of `nationality`
        let context:LocalContext = .init(local: _move nationality, context: self.packages)
        if      let selection:Selection<Composite> = context.local.routes.select(key, 
                    where: context.local.exists(_:))
        {
            // no excavation required, because we already filtered by extancy.
            let extant:GetRequest?
            switch link.disambiguator.disambiguate(_move selection, context: context) 
            {
            case .one(let composite):
                extant = .init(request, extant: composite, context: context, 
                    functions: self.functions.names)
            
            case .many(let choices):
                extant = .init(request, choices: choices, context: context,
                    functions: self.functions.names)
            }
            if let extant:GetRequest
            {
                return extant
            }
        }
        // second class: select symbols that existed at any time in `nationality`’s history
        else if let selection:Selection<Composite> = context.local.routes.select(key)
        {
            switch link.disambiguator.disambiguate(_move selection, context: context) 
            {
            case .one(let composite):
                if  let version:Version = context.local.excavate(composite), 
                    let request:GetRequest = .init(request, extant: composite, 
                        context: context.repinned(to: version, context: self.packages), 
                        functions: self.functions.names)
                {
                    return request
                }
            
            case .many(let choices):
                return .init(request, choices: choices, context: context,
                    functions: self.functions.names, 
                    migration: true)
            }
        }
        return nil
    }
}
