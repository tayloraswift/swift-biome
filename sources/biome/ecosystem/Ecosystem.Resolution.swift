extension Ecosystem 
{
    @usableFromInline
    enum Resolution
    {
        case selection(Selection, pins:[Package.Index: Version])
        
        case searchIndex(Package.Index)
        case sitemap(Package.Index)
    }
    
    func resolve<Path>(_ path:Path, root:Root, query:[URI.Parameter], stems:Stems) 
        -> (resolution:Resolution, redirected:Bool)?
        where Path:BidirectionalCollection, Path.Element:StringProtocol
    {
        switch root 
        {
        case .sitemap: 
            guard   let components:[Path.Element.SubSequence] = path.first?.split(separator: "."),
                    let package:Package.ID = components.first.map(Package.ID.init(_:)), 
                    let package:Package.Index = self.indices[package]
            else 
            {
                return nil 
            }
            return (.sitemap(package), false) 
        
        case .searchIndex: 
            guard   let package:Package.ID = path.first.map(Package.ID.init(_:)), 
                    let package:Package.Index = self.indices[package],
                    case "types"? = path.dropFirst().first
            else 
            {
                return nil 
            }
            return (.searchIndex(package), false) 
        
        case .article: 
            return self.resolveNamespace(path: path, query: query)
            {
                (implicit:Symbol.Link, namespace:Module.Index, arrival:MaskedVersion?) in 
                
                // passing a symbol link to ``Stems.subscript(_:_:)`` directly will 
                // strip the characters after the first hyphen in each component. 
                // so we need to manually re-extract the path components.
                if  let article:Article.ID = 
                        stems[namespace, implicit.map(\.string)].map(Article.ID.init(_:)),
                    let article:Article.Index = 
                        self[namespace.package].articles.indices[article]
                {
                    guard let pins:[Package.Index: Version] = self[namespace.package]
                        .versions[arrival]?.isotropic(culture: namespace.package)
                    else 
                    {
                        return nil
                    }
                    return (.selection(.article(article), pins: pins), false)
                }
                else if case (let resolution, _)? = 
                    self.resolveSymbolLink(implicit, 
                        namespace: namespace, 
                        arrival: arrival, 
                        stems: stems)
                {
                    return (resolution, true)
                }
                else 
                {
                    return nil 
                }
            } 
        
        case .master:
            return self.resolveNamespace(path: path, query: query)
            {
                self.resolveSymbolLink($0, namespace: $1, arrival: $2, stems: stems)
            } ?? (try? self.resolveAnyMatching(.init(query)))
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
            let package:Package = self[package]
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
                let pins:Package.Pins<Version> = destination.versions[arrival]
            {
                let pins:[Package.Index: Version] = 
                    pins.isotropic(culture: destination.index)
                return (.selection(.package(destination.index), pins: pins), false)
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
        else if let module:Module.Index = self[.swift]?.modules.indices[module]
        {
            namespace = module
        }
        else if let module:Module.Index = self[.core]?.modules.indices[module]
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
            if  let pins:Package.Pins<Version> = 
                self[namespace.package].versions[arrival]
            {
                let pins:[Package.Index: Version] = 
                    pins.isotropic(culture: namespace.package)
                return (.selection(.module(namespace), pins: pins), false)
            }
            else 
            {
                return nil
            }
        }
        return try select(implicit, namespace, arrival)
    }
    private 
    func resolveSymbolLink(_ implicit:Symbol.Link, 
        namespace:Module.Index, 
        arrival:MaskedVersion?, 
        stems:Stems)
        -> (resolution:Resolution, redirected:Bool)?
    {        
        if  case let (package, pins)? = 
                self.localize(destination: namespace.package, 
                    arrival: arrival, 
                    lens: implicit.query.lens),
            let route:Route = stems[namespace, implicit], 
            case let (selection, redirected: redirected)? = 
                self.selectWithRedirect(from: route, 
                    lens: .init(package, at: pins.local), 
                    by: implicit.disambiguator)
        {
            let pins:[Package.Index: Version] = pins.isotropic(culture: package.index)
            return (.selection(selection, pins: pins), redirected)
        }
        else 
        {
            return nil
        }
    }
}
// brute force id-based resolution 
extension Ecosystem 
{
    func resolveAnyMatching(_ query:Symbol.Link.Query) 
        -> (resolution:Resolution, redirected:Bool)?
    {
        guard let composite:Symbol.Composite = self.findAnyMatching(query)
        else 
        {
            return nil
        }
        if  case let (package, pins)? = 
            self.localize(destination: composite.culture.package, lens: query.lens), 
            package.contains(composite, at: pins.local)
        {
            let pins:[Package.Index: Version] = pins.isotropic(culture: package.index)
            return (.selection(.composite(composite), pins: pins), false)
        }
        else 
        {
            return nil
        }
    }
    private 
    func findAnyMatching(_ query:Symbol.Link.Query) -> Symbol.Composite?
    {
        guard   let base:Symbol.ID = query.base, 
                let base:Symbol.Index = self.findAnyMatching(base)
        else 
        {
            return nil 
        }
        guard   let host:Symbol.ID = query.host 
        else 
        {
            return .init(natural: base)
        }
        guard   let host:Symbol.Index = self.findAnyMatching(host)
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
    func findAnyMatching(_ id:Symbol.ID) -> Symbol.Index?
    {
        for package:Package in self.packages 
        {
            if let index:Symbol.Index = package.symbols.indices[id]
            {
                return index 
            }
        }
        return nil 
    }
}
