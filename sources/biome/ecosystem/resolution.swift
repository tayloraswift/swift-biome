extension Ecosystem 
{
    struct Resolution
    {
        let pins:[Package.Index: Version]
        let selection:Selection
        let temporary:Bool
        
        init(_ selection:Selection, pins:[Package.Index: Version], temporary:Bool = false)
        {
            self.selection = selection 
            self.temporary = temporary
            self.pins = pins 
        }
    }
    
    func resolve<Tail>(location global:Link.Reference<Tail>, keys:Route.Keys) 
        -> Resolution?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        let local:Link.Reference<Tail.SubSequence>
        
        let root:Package?
        if  let package:Package.ID = global.nation, 
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
        
        guard let module:Module.ID = qualified.namespace 
        else 
        {
            if  let nation:Package = root, 
                let pins:Package.Pins = nation.versions[arrival]
            {
                return .init(.package(nation.index), 
                    pins: pins.isotropic(culture: nation.index)) 
            }
            else 
            {
                return nil
            }
        } 
        
        let nation:Package
        let namespace:Module.Index
        if let root:Package 
        {
            guard let module:Module.Index = root.modules.indices[module]
            else 
            {
                return nil
            }
            (nation, namespace) = (root, module)
        }
        else if let swift:Package = self[.swift], 
                let module:Module.Index = swift.modules.indices[module]
        {
            (nation, namespace) = (swift, module)
        }
        else if let core:Package = self[.core], 
                let module:Module.Index = core.modules.indices[module]
        {
            (nation, namespace) = (core, module)
        }
        else 
        {
            return nil
        }
        
        let implicit:Link.Reference<Tail.SubSequence> = _move(qualified).dropFirst()
        
        guard let path:Path = .init(implicit)
        else 
        {
            if let pins:Package.Pins = nation.versions[arrival]
            {
                return .init(.module(namespace), 
                    pins: pins.isotropic(culture: nation.index))
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
        
        guard let localized:(package:Package, pins:Package.Pins) = 
            self.localize(nation: nation, arrival: arrival, lens: implicit.query.lens)
        else 
        {
            return nil
        }
        if case let (selection, redirected: redirected)? = 
            self.selectWithRedirect(from: route, 
                in: .init(localized.package, at: localized.pins.version), 
                by: implicit.disambiguator)
        {
            return .init(selection, 
                pins: localized.pins.isotropic(culture: localized.package.index), 
                temporary: redirected)
        }
        else 
        {
            return nil
        }
    }
}
