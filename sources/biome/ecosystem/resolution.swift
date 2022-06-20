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
        
        let nation:Package, 
            explicit:Bool
        if  let package:Package.ID = global.nation, 
            let package:Package = self[package]
        {
            explicit = true
            nation = package 
            local = global.dropFirst()
        }
        else if let swift:Package = self[.swift]
        {
            explicit = false
            nation = swift
            local = global[...]
        }
        else 
        {
            return nil
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
        
        guard let namespace:Module.ID = qualified.namespace 
        else 
        {
            if explicit, let pins:Package.Pins = nation.versions[arrival]
            {
                return .init(.package(nation.index), 
                    pins: pins.isotropic(culture: nation.index)) 
            }
            else 
            {
                return nil
            }
        } 
        guard let namespace:Module.Index = nation.modules.indices[namespace]
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
