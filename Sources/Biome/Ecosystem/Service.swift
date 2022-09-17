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
                if  let endpoint:GlobalLink.Endpoint = self._get(scheme: scheme, 
                        request: _move normalized)
                {
                    return self.response(for: endpoint, template: self.template)
                }
            }
        }
        return .init(uri: uri.description, results: .none, 
            payload: .init("page not found.")) 
    }

    func _get(scheme:Scheme, request:__owned GlobalLink) -> GlobalLink.Endpoint?
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
        -> GlobalLink.Endpoint?
    {
        try? self._get(scheme: scheme, residency: _move residency, request: request)
    }
    func _get(scheme:Scheme, implicit residency:__owned Package, request:__owned GlobalLink) 
        -> GlobalLink.Endpoint?
    {
        guard   let endpoint:GlobalLink.Endpoint = try? self._get(scheme: scheme, 
                    residency: _move residency, 
                    request: request)
        else 
        {
            return nil 
        }
        if case .target(.package) = endpoint.request
        {
            return nil 
        }
        else 
        {
            return endpoint
        }
    }
    func _get(scheme:Scheme, residency:__owned Package, request:__owned GlobalLink) 
        throws -> GlobalLink.Endpoint?
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

        // we must parse the symbol link *now*, otherwise references to things 
        // like global vars (`Swift.min(_:_:)`) won’t work
        guard let request:_SymbolLink = try .init(request)
        else 
        {
            return .init(.package(residency.nationality), version: arrival)
        }
        //  we can store a module id in a ``Symbol/Link``, because every 
        //  ``Module/ID`` is a valid ``Symbol/Link/Component``.
        let residency:Package.Pinned = .init(_move residency, version: arrival)
        guard let namespace:Tree.Position<Module> = residency.modules.find(.init(request.first))
        else 
        {
            return nil
        }
        guard let request:_SymbolLink = request.suffix 
        else 
        {
            return .init(.module(namespace.contemporary), version: arrival)
        }

        if  let nationality:_SymbolLink.Nationality = request.nationality,
            let package:Package = self.packages[nationality.id],
            let version:Version = 
                nationality.version.map(package.tree.find(_:)) ?? package.tree.default,
            let endpoint:GlobalLink.Endpoint.Request = self._get(scheme: scheme, 
                nationality: .init(_move package, version: version), 
                namespace: namespace.contemporary, 
                request: request) 
        {
            return .init(endpoint, version: version)
        }
        return self._get(scheme: scheme, nationality: _move residency, 
            namespace: namespace.contemporary, 
            request: request).map 
        {
            .init($0, version: arrival)
        }
    }
    func _get(scheme:Scheme, nationality:__owned Package.Pinned, 
        namespace:Branch.Position<Module>, 
        request:__owned _SymbolLink)
        -> GlobalLink.Endpoint.Request?
    {
        if      case .doc = scheme, 
                let key:Route.Key = self.stems[namespace, straight: request], 
                let article:Tree.Position<Article> = nationality.articles.find(.init(key))
        {
            return .target(.article(article.contemporary))
        }

        let request:_SymbolLink = request.disambiguated()

        guard   let key:Route.Key = self.stems[namespace, request]
        else 
        {
            return nil 
        }

        let context:Package.Context = .init(local: _move nationality, context: self.packages)

        if      var selection:_Selection<Branch.Composite> = context.local.routes.select(key, 
                    where: context.local.exists(_:))
        {
            request.disambiguator.disambiguate(&selection, context: context) 
            switch selection
            {
            case .one(let composite): 
                return .target(.composite(composite))
            case .many(let composites): 
                return .disambiguation(composites)
            }
        }
        else if var selection:_Selection<Branch.Composite> = context.local.routes.select(key, 
                    where: { _ in true })
        {
            request.disambiguator.disambiguate(&selection, context: context) 
            switch selection 
            {
            case .one(let composite):
                return .target(.composite(composite))
            case .many(let composites):
                return .disambiguation(composites)
            }
        }
        else 
        {
            return nil
        }
    }
}

extension Service 
{
    func response(for endpoint:GlobalLink.Endpoint, template:DOM.Flattened<Page.Key>) 
        -> WebSemantics.Response<Resource>
    {
        fatalError("unimplemented")
    }
}