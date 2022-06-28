extension Ecosystem 
{
    enum Resolution
    {
        case selection(Selection, pins:[Package.Index: Version])
        case searchIndex(Package.Index)
    }
    
    func resolve<Path>(_ path:Path, prefix:URI.Prefix, query:[URI.Parameter], stems:Stems) 
        -> (resolution:Resolution, redirected:Bool)?
        where Path:BidirectionalCollection, Path.Element:StringProtocol
    {
        switch prefix 
        {
        case .lunr: 
            guard   let package:Package.ID = path.first.map(Package.ID.init(_:)), 
                    let package:Package.Index = self.indices[package],
                    case "types"? = path.dropFirst().first
            else 
            {
                return nil 
            }
            return (.searchIndex(package), false) 
        
        case .doc: 
            return self.resolveNamespace(path)
            {
                (path:Path.SubSequence, namespace:Module.Index, arrival:MaskedVersion?) in 
                
                if  let route:Route = stems[namespace, path],
                    let article:Article.Index = 
                        self[namespace.package].articles.indices[route]
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
                    self.resolveSymbol(path, namespace: namespace, arrival: arrival, 
                        query: query, 
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
            return self.resolveNamespace(path)
            {
                self.resolveSymbol($0, namespace: $1, arrival: $2, 
                    query: query, 
                    stems: stems)
            }
        }
    }

    private 
    func resolveNamespace<Path>(_ path:Path, 
        then select:(Path.SubSequence, Module.Index, MaskedVersion?) 
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
        
        guard let module:Module.ID = qualified.first.map(Module.ID.init(_:)) 
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
        
        let implicit:Path.SubSequence = _move(qualified).dropFirst()
        if  implicit.isEmpty
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
        else 
        {
            return try select(implicit, namespace, arrival)
        }
    }
    private 
    func resolveSymbol<Path>(_ path:Path, 
        namespace:Module.Index, 
        arrival:MaskedVersion?, 
        query:[URI.Parameter], 
        stems:Stems)
        -> (resolution:Resolution, redirected:Bool)?
        where Path:Collection, Path.Element:StringProtocol
    {        
        if  let link:Symbol.Link = 
                try? .init(path: (path, path.startIndex), query: query), 
            case let (package, pins)? = 
                self.localize(destination: namespace.package, 
                    arrival: arrival, 
                    lens: link.query.lens),
            let route:Route = stems[namespace, link.revealed], 
            case let (selection, redirected: redirected)? = 
                self.selectWithRedirect(from: route, 
                    lens: .init(package, at: pins.local), 
                    by: link.disambiguator)
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
