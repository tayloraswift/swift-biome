import Versions
import Resources
import DOM

extension Ecosystem 
{
    enum Redirect
    {
        case index(Index, pins:Package.Pins, template:DOM.Template<Page.Key>? = nil)
        case resource(Resource)
    }
    
    @usableFromInline
    enum Resolution
    {
        case index(Index, pins:Package.Pins, exhibit:Version? = nil, template:DOM.Template<Page.Key>? = nil)
        
        case choices([Symbol.Composite], pins:Package.Pins)
        case resource(Resource, uri:URI)
        
        init(_ selection:Packages.Selection, pins:Package.Pins)
        {
            switch selection 
            {
            case .one(let composite): 
                self = .index(.composite(composite), pins: pins)
            case .many(let composites):
                self = .choices(composites, pins: pins)
            }
        }
    }
    
    @usableFromInline
    func resolve(path:[String], query:[URI.Parameter]) 
        -> (resolution:Resolution, redirected:Bool)?
    {
        if  let root:String = path.first, 
            let root:Route.Stem = self.stems[leaf: root],
            let root:Root = self.roots[root],
            case let (resolution, redirected)? = self.resolve(root: root,
                path: path.dropFirst(), 
                query: query) 
        {
            return (resolution, redirected)
        }
        else 
        {
            return nil 
        }
    }
    
    private 
    func resolve<Path>(root:Root, path:Path, query:[URI.Parameter]) 
        -> (resolution:Resolution, redirected:Bool)?
        where Path:BidirectionalCollection, Path.Element:StringProtocol
    {
        switch root 
        {
        case .sitemap: 
            guard   let components:[Path.Element.SubSequence] = path.first?.split(separator: "."),
                    let package:Package.ID = components.first.map(Package.ID.init(_:)), 
                    let package:Package.Index = self.packages.indices[package], 
                    let sitemap:Resource = self.caches[package]?.sitemap
            else 
            {
                return nil 
            }
            return (.resource(sitemap, uri: self.uriOfSiteMap(for: package)), false) 
        
        case .searchIndex: 
            guard   let package:Package.ID = path.first.map(Package.ID.init(_:)), 
                    let package:Package.Index = self.packages.indices[package],
                    case "types"? = path.dropFirst().first, 
                    let search:Resource = self.caches[package]?.search
            else 
            {
                return nil 
            }
            return (.resource(search, uri: self.uriOfSearchIndex(for: package)), false) 
        
        case .article: 
            return self.resolveNamespace(path: path, query: query)
            {
                (implicit:Symbol.Link, namespace:Module.Index, arrival:MaskedVersion?) in 
                
                // passing a symbol link to ``Stems.subscript(_:_:)`` directly will 
                // strip the characters after the first hyphen in each component. 
                // so we need to manually re-extract the path components.
                if  let article:Article.ID = 
                        self.stems[namespace, implicit.map(\.string)].map(Article.ID.init(_:)),
                    let article:Article.Index = 
                        self[namespace.package].articles.indices[article]
                {
                    if let pins:Package.Pins = self[namespace.package].versions.pins(at: arrival)
                    {
                        return (.index(.article(article), pins: pins), false)
                    }
                    else 
                    {
                        return nil
                    }
                }
                else if case (let resolution, _)? = 
                    self.resolveSymbol(link: implicit, 
                        namespace: namespace, 
                        arrival: arrival)
                {
                    return (resolution, true)
                }
                else 
                {
                    return nil 
                }
            } 
        
        case .master:
            if path.isEmpty 
            {
                return try? self.resolveAnySymbol(matching: .init(query))
            }
            return self.resolveNamespace(path: path, query: query)
            {
                self.resolveSymbol(link: $0, namespace: $1, arrival: $2) ?? 
                self.resolveSymbol(legacyLink: $0, namespace: $1, arrival: $2)
            }
        }
    }

    private 
    func resolveNamespace<Path>(path:Path, query:[URI.Parameter],
        then select:(Symbol.Link, Module.Index, MaskedVersion?) 
        throws   -> (resolution:Resolution, redirected:Bool)?) 
        rethrows -> (resolution:Resolution, redirected:Bool)?
        where Path:Collection, Path.Element:StringProtocol
    {
        let local:Path.SubSequence
        
        let root:Package?
        if  let package:Package.ID = path.first.map(Package.ID.init(_:)), 
            let package:Package = self.packages[package]
        {
            root = package 
            local = path.dropFirst()
        }
        else 
        {
            root = nil
            local = path[...]
        }
        
        let qualified:Path.SubSequence
        let arrival:MaskedVersion?
        if let version:MaskedVersion = local.first.flatMap(MaskedVersion.init(_:))
        {
            qualified = _move(local).dropFirst()
            arrival = version 
        }
        else 
        {
            qualified = _move(local) 
            arrival = nil
        }
        // we must parse the symbol link *now*, otherwise references to things 
        // like global vars (`Swift.min(_:_:)`) won’t work
        guard let link:Symbol.Link = 
            try? .init(path: _move(qualified), query: query).revealed
        else 
        {
            // every article path is a valid symbol link (just with extra 
            // interceding hyphens). so if parsing failed, it was not a valid 
            // article path either.
            return nil 
        }
        //  we can store a module id in a ``Symbol/Link``, because every 
        //  ``Module/ID`` is a valid ``Symbol/Link/Component``.
        guard let module:Module.ID = (link.first?.string).map(Module.ID.init(_:)) 
        else 
        {
            if  let destination:Package = root, 
                let pins:Package.Pins = destination.versions.pins(at: arrival)
            {
                return (.index(.package(destination.index), pins: pins), false)
            }
            else 
            {
                return nil
            }
        } 
        
        let namespace:Module.Index
        if let root:Package 
        {
            guard let module:Module.Index = root.modules.indices[module]
            else 
            {
                return nil
            }
            namespace = module
        }
        else if let module:Module.Index = self.packages[.swift]?.modules.indices[module]
        {
            namespace = module
        }
        else if let module:Module.Index = self.packages[.core]?.modules.indices[module]
        {
            namespace = module
        }
        else 
        {
            return nil
        }
        
        guard let implicit:Symbol.Link = _move(link).suffix
        else 
        {
            if let pins:Package.Pins = self[namespace.package].versions.pins(at: arrival)
            {
                return (.index(.module(namespace), pins: pins), false)
            }
            else 
            {
                return nil
            }
        }
        return try select(implicit, namespace, arrival)
    }
    private 
    func resolveSymbol(link implicit:Symbol.Link, 
        namespace:Module.Index, 
        arrival:MaskedVersion?)
        -> (resolution:Resolution, redirected:Bool)?
    {
        guard   let pins:Package.Pins = self.packages.localize(
                    destination: namespace.package, 
                    arrival: arrival, 
                    lens: implicit.query.lens),
                let route:Route.Key = self.stems[namespace, implicit]
        else 
        {
            return nil 
        }
        
        let package:Package = self[pins.local.package]
        // each “select” call is currently O(n^2), but we could make it 
        // O(n log(n)) with some effort
        if case (let selection, redirected: let redirected)? = 
                self.packages.selectExtantWithRedirect(route, 
                    lens: .init(package, at: pins.local.version), 
                    by: implicit.disambiguator)
        {
            return (.init(selection, pins: pins), redirected)
        }
        else if case (.one(let composite), redirected: let redirected)? = 
                self.packages.selectHistoricalWithRedirect(route, lens: package, 
                    by: implicit.disambiguator)
        {
            // we have no idea what version any of the historical selections 
            // came from. to determine this, travel backwards through all 
            // lens-package versions until we find one that contains the selection. 
            // to keep the complexity from becoming cubic; only do this for 
            // unambiguous references...
            for version:Version in package.versions.indices.reversed() 
            {
                if package.contains(composite, at: version) 
                {
                    let resolution:Resolution = .index(.composite(composite), 
                        pins: package.versions.pins(at: version), 
                        exhibit: pins.local.version)
                    return (resolution, redirected)
                }
            }
        }
        return nil
    }
}
// brute force compatibility resolution 
extension Ecosystem 
{
    private 
    func resolveSymbol(legacyLink implicit:Symbol.Link, 
        namespace:Module.Index, 
        arrival:MaskedVersion?)
        -> (resolution:Resolution, redirected:Bool)?
    {
        guard   case nil = implicit.query.lens, 
                let route:Route.Key = self.stems[namespace, implicit]
        else 
        {
            return nil
        }
        for package:Package.ID in self.whitelist
        {
            guard   let package:Package = self.packages[package], 
                        package.index != namespace.package,
                    let pins:Package.Pins = package.versions.pins(at: nil),
                    case (let selection, redirected: let redirected)? = 
                        self.packages.selectExtantWithRedirect(route, 
                            lens: .init(package, at: pins.local.version), 
                            by: implicit.disambiguator)
            else 
            {
                continue 
            }
            return (.init(selection, pins: pins), redirected)
        }
        return nil
    }
}
// brute force id-based resolution 
extension Ecosystem 
{
    func resolveAnySymbol(matching query:Symbol.Link.Query) 
        -> (resolution:Resolution, redirected:Bool)?
    {
        guard let composite:Symbol.Composite = self.findAnySymbol(matching: query)
        else 
        {
            return nil
        }
        if  let pins:Package.Pins = self.packages.localize(
                destination: composite.culture.package, 
                lens: query.lens)//, 
            //package.contains(composite, at: pins.local)
        {
            return (.index(.composite(composite), pins: pins), false)
        }
        else 
        {
            return nil
        }
    }
    private 
    func findAnySymbol(matching query:Symbol.Link.Query) -> Symbol.Composite?
    {
        guard   let base:Symbol.ID = query.base, 
                let base:Symbol.Index = self.findAnySymbol(matching: base)
        else 
        {
            return nil 
        }
        guard   let host:Symbol.ID = query.host 
        else 
        {
            return .init(natural: base)
        }
        guard   let host:Symbol.Index = self.findAnySymbol(matching: host)
        else 
        {
            return nil 
        }
        // a (base, host) pair is actually still not enough to uniquely 
        // disambiguate a symbol, since symbols can still overload on culture. 
        // for now, assume the culture is the same as the host’s culture.
        return .init(base, .init(natural: host))
    }
    private 
    func findAnySymbol(matching id:Symbol.ID) -> Symbol.Index?
    {
        for package:Package.ID in self.whitelist  
        {
            if let index:Symbol.Index = self.packages[package]?.symbols.indices[id]
            {
                return index 
            }
        }
        return nil 
    }
} 
