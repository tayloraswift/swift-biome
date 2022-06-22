extension Ecosystem 
{
    enum Resolution
    {
        case selection(Selection, pins:[Package.Index: Version])
        case searchIndex(Package.Index)
    }
    
    func resolve<Tail>(prefix:URI.Prefix, global:Link.Reference<Tail>, keys:Route.Keys) 
        -> (resolution:Resolution, redirected:Bool)?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        switch prefix 
        {
        case .lunr: 
            guard   let package:Package.ID = global.package, 
                    let package:Package.Index = self.indices[package],
                    case "types"? = global.dropFirst().first?.identifier
            else 
            {
                return nil 
            }
            return (.searchIndex(package), false) 
        
        case .doc: 
            return self.resolveRoute(global, keys: keys)
            {
                (
                    destination:Package, 
                    arrival:MaskedVersion?, 
                    route:Route, 
                    suffix:Link.Reference<Tail.SubSequence>
                ) in 
                
                if let article:Article.Index = destination.articles.indices[route]
                {
                    guard let pins:[Package.Index: Version] = destination
                        .versions[arrival]?.isotropic(culture: destination.index)
                    else 
                    {
                        return nil
                    }
                    return (.selection(.article(article), pins: pins), false)
                }
                else if let resolution:Resolution = 
                    self.resolveSuffix(destination, arrival, route, suffix)?.resolution
                {
                    return (resolution, true)
                }
                else 
                {
                    return nil 
                }
            } 
        
        case .master:
            return self.resolveRoute(global, keys: keys, 
                then: self.resolveSuffix(_:_:_:_:))
        }

    }

    private 
    func resolveRoute<Tail>(_ global:Link.Reference<Tail>, keys:Route.Keys, 
        then select:(Package, MaskedVersion?, Route, Link.Reference<Tail.SubSequence>) 
        throws   -> (resolution:Resolution, redirected:Bool)?) 
        rethrows -> (resolution:Resolution, redirected:Bool)?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        let local:Link.Reference<Tail.SubSequence>
        
        let root:Package?
        if  let package:Package.ID = global.package, 
            let package:Package = self[package]
        {
            root = package 
            local = global.dropFirst()
        }
        else 
        {
            root = nil
            local = global[...]
        }
        
        let qualified:Link.Reference<Tail.SubSequence>
        let arrival:MaskedVersion?
        if let version:MaskedVersion = local.arrival
        {
            qualified = _move(local).dropFirst()
            arrival = version 
        }
        else 
        {
            qualified = _move(local) 
            arrival = nil
        }
        
        guard let module:Module.ID = qualified.module 
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
        
        let destination:Package
        let namespace:Module.Index
        if let root:Package 
        {
            guard let module:Module.Index = root.modules.indices[module]
            else 
            {
                return nil
            }
            (destination, namespace) = (root, module)
        }
        else if let swift:Package = self[.swift], 
                let module:Module.Index = swift.modules.indices[module]
        {
            (destination, namespace) = (swift, module)
        }
        else if let core:Package = self[.core], 
                let module:Module.Index = core.modules.indices[module]
        {
            (destination, namespace) = (core, module)
        }
        else 
        {
            return nil
        }
        
        let implicit:Link.Reference<Tail.SubSequence> = _move(qualified).dropFirst()
        
        guard let path:Path = .init(implicit)
        else 
        {
            if let pins:Package.Pins<Version> = destination.versions[arrival]
            {
                let pins:[Package.Index: Version] = 
                    pins.isotropic(culture: destination.index)
                return (.selection(.module(namespace), pins: pins), false)
            }
            else 
            {
                return nil
            }
        }
        guard let route:Route = keys[namespace, path, implicit.orientation]
        else 
        {
            return nil
        }
        
        return try select(destination, arrival, route, implicit)
    }
    private 
    func resolveSuffix<Tail>(
        _ destination:Package, 
        _ arrival:MaskedVersion?, 
        _ route:Route, 
        _ suffix:Link.Reference<Tail>)
        -> (resolution:Resolution, redirected:Bool)?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        guard let localized:(package:Package, pins:Package.Pins<Version>) = 
            self.localize(destination: destination, arrival: arrival, 
                lens: suffix.query.lens)
        else 
        {
            return nil
        }
        if case let (selection, redirected: redirected)? = 
            self.selectWithRedirect(from: route, 
                in: .init(localized.package, at: localized.pins.local), 
                by: suffix.disambiguator)
        {
            let pins:[Package.Index: Version] = 
                localized.pins.isotropic(culture: localized.package.index)
            return (.selection(selection, pins: pins), redirected)
        }
        else 
        {
            return nil
        }
    }
}
