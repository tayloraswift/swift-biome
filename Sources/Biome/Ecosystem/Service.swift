import Resources
import WebSemantics
import DOM
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

    private 
    var functions:Functions
    // private 
    var packages:Packages, 
        stems:Route.Stems
    
    //private
    var template:DOM.Flattened<Page.Key>




    var logo:[UInt8]
    {
        fatalError("obsoleted")
    }
    var whitelist:[Package.ID]
    {
        fatalError("obsoleted")
    }
    
    var roots:[Route.Stem: Root]
    {
        fatalError("obsoleted")
    }
    var root:
    (    
        master:URI,
        article:URI,
        sitemap:URI,
        searchIndex:URI
    )
    {
        fatalError("obsoleted")
    }
    var redirects:[String: Redirect]
    {
        get 
        {
            fatalError("obsoleted")
        }
        set 
        {
            fatalError("obsoleted")
        }
    }
    var caches:[Package.Index: Cache]
    {
        get 
        {
            fatalError("obsoleted")
        }
        set 
        {
            fatalError("obsoleted")
        }
    }

    public 
    init() 
    {
        self.functions = .init([:])
        self.packages = .init()
        self.stems = .init()

        self.template = .init(freezing: Page.html)
    }
}
extension Service 
{
    @discardableResult
    public mutating 
    func updatePackage(_ id:Package.ID, 
        resolved:PackageResolution,
        branch:String, 
        fork:String? = nil,
        date:Date, 
        tag:String? = nil,
        graphs:[SymbolGraph]) throws -> Package.Index
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

struct DocumentationQuery
{
    let target:GlobalLink.Target 
    let version:Version 

    let _objects:Never?

    var nationality:Package.Index 
    {
        switch self.target 
        {
        case .package(let nationality): 
            return nationality 
        case .module(let module): 
            return module.nationality 
        case .article(let article): 
            return article.nationality 
        case .composite(let composite): 
            return composite.nationality 
        }
    }
}
struct SelectionQuery
{
    let nationality:Package.Index
    let version:Version 
    let choices:[Composite]
}
struct MigrationQuery 
{
    let nationality:Package.Index
    /// The requested version. None of the symbols in this query 
    /// exist in this version.
    let requested:Version
    /// The list of potentially matching compounds.
    /// 
    /// It is not possible to efficiently look up the most 
    /// recent version a compound appears in. Therefore, when 
    /// generating a URL for a compound choice, we should maximally 
    /// disambiguate it, and allow HTTP redirection to resolve it 
    /// to an appropriate version, should a user click on that URL.
    let compounds:[Compound]
    /// The list of potentially matching atoms, along with 
    /// the most recent version (before ``requested``) they 
    /// appeared in.
    let atoms:[(Atom<Symbol>, Version)]
}

struct GetRequest 
{
    enum Query 
    {
        case redirect 
        case documentation(DocumentationQuery)
        case selection(SelectionQuery)
        case migration(MigrationQuery)
    }

    let uri:URI
    var query:Query

    init(uri:URI, query:DocumentationQuery)
    {
        self.uri = uri 
        self.query = .documentation(query)
    }
    init(uri:URI, query:SelectionQuery)
    {
        self.uri = uri 
        self.query = .selection(query)
    }
    init(uri:URI, query:MigrationQuery)
    {
        self.uri = uri 
        self.query = .migration(query)
    }
}

extension Service 
{
    func get(_ uri:URI) -> WebSemantics.Response<Resource>
    {
        var normalized:GlobalLink = .init(uri)

        if  let first:String = normalized.descend(), 
            let function:Function = self.functions[first]
        {
            switch function 
            {
            case .sitemap: 
                break 
            case .lunr: 
                break 
            
            case .documentation(let scheme):
                if  let endpoint:GetRequest = self._get(scheme: scheme, 
                        request: _move normalized)
                {
                    return self.response(for: endpoint, template: self.template)
                }
            }
        }
        return .init(uri: uri.description, results: .none, 
            payload: .init("page not found.")) 
    }

    func _get(scheme:Scheme, request:__owned GlobalLink) -> GetRequest?
    {
        var request:GlobalLink = _move request
        if  let residency:Package = request.descend(where: { self.packages[.init($0)] }) 
        {
            return self._get(scheme: scheme, explicit: _move residency, request: _move request)
        }
        return  
            self._get(scheme: scheme, implicit: self.packages.swift, request: request) ?? 
            self._get(scheme: scheme, implicit: self.packages.core, request: request)
    }
    func _get(scheme:Scheme, explicit residency:__owned Package, request:__owned GlobalLink) 
        -> GetRequest?
    {
        try? self._get(scheme: scheme, residency: _move residency, request: request)
    }
    func _get(scheme:Scheme, implicit residency:__owned Package, request:__owned GlobalLink) 
        -> GetRequest?
    {
        guard   let request:GetRequest = try? self._get(scheme: scheme, 
                    residency: _move residency, 
                    request: request)
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
    func _get(scheme:Scheme, residency:__owned Package, request:__owned GlobalLink) 
        throws -> GetRequest?
    {
        var request:GlobalLink = request
        let arrival:Version? = request.descend 
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
        guard let request:_SymbolLink = try .init(request)
        else 
        {
            let uri:URI = residency.address().uri(functions: self.functions)
            return .init(uri: uri, query: .init(target: .package(residency.nationality), 
                version: residency.version, 
                _objects: nil))
        }
        //  we can store a module id in a ``Symbol/Link``, because every 
        //  ``Module/ID`` is a valid ``Symbol/Link/Component``.
        guard let namespace:PluralPosition<Module> = residency.modules.find(.init(request.first))
        else 
        {
            return nil
        }
        guard let request:_SymbolLink = request.suffix 
        else 
        {
            let address:Address = residency.address(of: residency.package.tree[local: namespace])
            let uri:URI = address.uri(functions: self.functions) 
            return .init(uri: uri, query: .init(target: .module(namespace.contemporary), 
                version: residency.version, 
                _objects: nil))
        }
        // doc scheme never uses nationality query parameter 
        if      case .doc = scheme, 
                let key:Route = self.stems[namespace.contemporary, straight: request], 
                let article:PluralPosition<Article> = residency.articles.find(.init(key))
        {
            let address:Address = residency.address(of: residency.package.tree[local: article], 
                namespace: residency.package.tree[local: namespace])
            let uri:URI = address.uri(functions: self.functions) 
            return .init(uri: uri, query: .init(target: .article(article.contemporary), 
                version: residency.version, 
                _objects: nil))
        }
        else if let nationality:_SymbolLink.Nationality = request.nationality,
                let package:Package = self.packages[nationality.id],
                let version:Version = 
                    nationality.version.map(package.tree.find(_:)) ?? package.tree.default,
                let endpoint:GetRequest = self._get(scheme: scheme, 
                    nationality: .init(_move package, version: version), 
                    namespace: namespace.contemporary, 
                    request: request.disambiguated()) 
        {
            return endpoint
        }
        return self._get(scheme: scheme, 
            nationality: _move residency, 
            namespace: namespace.contemporary, 
            request: request.disambiguated())
    }
    func _get(scheme:Scheme, nationality:__owned Package.Pinned, namespace:Atom<Module>, 
        request:__owned _SymbolLink) -> GetRequest?
    {
        guard let key:Route = self.stems[namespace, request]
        else 
        {
            return nil 
        }

        let context:Package.Context = .init(local: _move nationality, context: self.packages)

        if      let selection:_Selection<Composite> = context.local.routes.select(key, 
                    where: context.local.exists(_:))
        {
            switch request.disambiguator.disambiguate(_move selection, context: context) 
            {
            case .one(let composite):
                if  let uri:URI = context.address(of: composite)?.uri(functions: self.functions)
                {
                    return .init(uri: uri, query: .init(target: .composite(composite), 
                        version: context.local.version, 
                        _objects: nil))
                }
            
            case .many(let composites):
                if  let exemplar:Composite = composites.first, 
                    let address:Address = context.address(of: exemplar, disambiguate: false)
                {
                    let uri:URI = address.uri(functions: self.functions)
                    return .init(uri: uri, query: .init(nationality: context.local.nationality,
                        version: context.local.version, 
                        choices: composites))
                }
            }
        }
        else if let selection:_Selection<Composite> = context.local.routes.select(key)
        {
            switch request.disambiguator.disambiguate(_move selection, context: context) 
            {
            case .one(let composite):
                break
            case .many(let composites):
                break
            }
        }

        return nil
    }
}

extension Service 
{
    func response(for endpoint:GetRequest, template:DOM.Flattened<Page.Key>) 
        -> WebSemantics.Response<Resource>
    {
        fatalError("unimplemented")
    }
}
