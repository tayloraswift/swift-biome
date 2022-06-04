extension Ecosystem 
{
    func resolveLinkWithRedirect(
        parsing string:String, 
        lexicon:Lexicon,
        imports:Set<Module.Index>, 
        nest:Symbol.Nest?) 
        -> Link
    {
        // must attempt to parse absolute first, otherwise 
        // '/foo' will parse to ["", "foo"]
        let resolution:Link.Resolution?
        let visible:Int
        if let absolute:Link.Expression = try? .init(absolute: string)
        {
            visible = absolute.visible
            resolution = self.resolveGlobalLinkWithRedirect(absolute.reference, 
                lexicon: lexicon)
        }
        else if let relative:Link.Expression = try? .init(relative: string)
        {
            visible = relative.visible
            resolution = self.resolveVisibleLinkWithRedirect(relative.reference, 
                lexicon: lexicon,
                imports: imports, 
                nest: nest)
        }
        else 
        {
            print(self.describe(.none(string)))
            return .unresolved(string)
        }
        switch resolution
        {
        case nil: 
            print(self.describe(.none(string)))
            return .unresolved(string)
        
        case .one(let target): 
            return .resolved(target, visible: visible)
        
        case .many(let possibilities):
            print(self.describe(.many(string, possibilities)))
            return .unresolved(string)
        }
    }
    
    func resolveGlobalLinkWithRedirect<Tail>(_ link:Link.Reference<Tail>, keys:Route.Keys) 
        -> Link.Resolution?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        let global:Link.Reference<Tail.SubSequence> = link.dropFirst()
        let local:Link.Reference<Tail.SubSequence>
        
        let nation:Package, 
            explicit:Bool
        if  let package:Package.ID = global.nation, 
            let package:Package = self[package]
        {
            explicit = true
            nation = package 
            local = _move(global).dropFirst()
        }
        else if let swift:Package = self[.swift]
        {
            explicit = false
            nation = swift
            local = _move(global)
        }
        else 
        {
            return nil
        }
        
        let qualified:Link.Reference<Tail.SubSequence>
        let arrival:Version? 
        if let version:Version = local.arrival
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
            return explicit ? .one(.package(nation.index)) : nil
        } 
        guard let namespace:Module.Index = nation.modules.indices[namespace]
        else 
        {
            return nil
        }
        
        return self.resolveImplicitLinkWithRedirect(qualified.dropFirst(), 
            namespace: namespace, 
            arrival: arrival,
            nation: nation.index, 
            keys: keys)
    }
    
    private 
    func resolveGlobalLinkWithRedirect<Tail>(_ link:Link.Reference<Tail>, lexicon:Lexicon)
        -> Link.Resolution?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        guard   let nation:Package.ID = link.nation, 
                let nation:Package.Index = self.indices[nation]
        else 
        {
            return nil 
        }
        
        let qualified:Link.Reference<Tail.SubSequence> = link.dropFirst()
        
        guard let namespace:Module.ID = qualified.namespace 
        else 
        {
            return .one(.package(nation))
        }
        // if the global path starts with a package/namespace that 
        // matches one of our dependencies, treat it like a qualified 
        // reference. 
        if  case nil = qualified.query.lens, 
            let namespace:Module.Index = lexicon.namespaces[namespace], 
                namespace.package == nation
        {
            return self.resolveImplicitLinkWithRedirect([], qualified.dropFirst(), 
                namespace: namespace, 
                lexicon: lexicon)
        }
        else if let namespace:Module.Index = self[nation].modules.indices[namespace]
        {
            return self.resolveImplicitLinkWithRedirect(qualified.dropFirst(), 
                namespace: namespace, 
                arrival: nil,
                nation: nation, 
                keys: lexicon.keys)
        }
        else 
        {
            return nil
        }
    } 
}
extension Ecosystem 
{
    func resolveVisibleLinkWithRedirect<Tail>(
        _ link:Link.Reference<Tail>, 
        lexicon:Lexicon,
        imports:Set<Module.Index> = [], 
        nest:Symbol.Nest? = nil) 
        -> Link.Resolution?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        if  let resolution:Link.Resolution = self.resolveVisibleLink(link, 
                lexicon: lexicon, 
                imports: imports, 
                nest: nest)
        {
            return resolution 
        }
        else if let link:Link.Reference<Tail> = link.outed, 
            let resolution:Link.Resolution = self.resolveVisibleLink(link, 
                lexicon: lexicon, 
                imports: imports, 
                nest: nest)
        {
            return resolution
        }
        else 
        {
            return nil
        }
    }
    
    private 
    func resolveVisibleLink<Tail>(
        _ link:Link.Reference<Tail>, 
        lexicon:Lexicon,
        imports:Set<Module.Index> = [], 
        nest:Symbol.Nest? = nil) 
        -> Link.Resolution?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        if  let qualified:Link.Resolution = 
            self.resolveQualifiedLink(link, lexicon: lexicon)
        {
            return qualified
        }
        if  let nest:Symbol.Nest = nest, 
            lexicon.culture == nest.namespace || imports.contains(nest.namespace), 
            let relative:Link.Resolution = 
            self.resolveImplicitLink(nest.prefix, link, namespace: nest.namespace,  lexicon: lexicon)
        {
            return relative
        }
        if  let absolute:Link.Resolution = 
            self.resolveImplicitLink([],          link, namespace: lexicon.culture, lexicon: lexicon) 
        {
            return absolute
        }
        var imported:Link.Resolution? = nil 
        for namespace:Module.Index in imports where namespace != lexicon.culture 
        {
            if  let absolute:Link.Resolution = 
                self.resolveImplicitLink([], link, namespace: namespace, lexicon: lexicon) 
            {
                if case nil = imported 
                {
                    imported = absolute
                }
                else 
                {
                    // name collision
                    return nil 
                }
            }
        }
        return imported 
    }
    private 
    func resolveQualifiedLink<Tail>(_ link:Link.Reference<Tail>, lexicon:Lexicon) 
        -> Link.Resolution?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        // check if the first component refers to a module. it can be the same 
        // as its own culture, or one of its dependencies. 
        
        // ``modulename/typename.membername(_:)``
        if  let namespace:Module.ID = link.namespace, 
            let namespace:Module.Index = lexicon.namespaces[namespace]
        {
            return self.resolveImplicitLink([], link.dropFirst(), 
                namespace: namespace, 
                lexicon: lexicon)
        }
        else 
        {
            return nil
        }
    }
    private 
    func resolveImplicitLink<Tail>(
        _ prefix:[String], 
        _ link:Link.Reference<Tail>, 
        namespace:Module.Index, 
        lexicon:Lexicon) 
        -> Link.Resolution?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        guard let path:Path = .init(prefix, link)
        else 
        {
            return .one(.module(namespace))
        }
        guard let route:Route = lexicon.keys[namespace, path, link.orientation]
        else 
        {
            return nil
        }
        return .init(self.select(from: route, lexicon: lexicon, 
            disambiguator: link.disambiguator))
    }
    private 
    func resolveImplicitLinkWithRedirect<Tail>(
        _ prefix:[String], 
        _ link:Link.Reference<Tail>, 
        namespace:Module.Index, 
        lexicon:Lexicon) 
        -> Link.Resolution?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        guard let path:Path = .init(prefix, link)
        else 
        {
            return .one(.module(namespace))
        }
        guard let route:Route = lexicon.keys[namespace, path, link.orientation]
        else 
        {
            return nil
        }
        if  let resolution:Link.Resolution = .init(
            self.select(from: route, lexicon: lexicon, disambiguator: link.disambiguator))
        {
            return resolution
        }
        else if let route:Route = route.outed, 
            let resolution:Link.Resolution = .init(
            self.select(from: route, lexicon: lexicon, disambiguator: link.disambiguator))
        {
            return resolution
        }
        else 
        {
            return nil
        }
    }
    private 
    func resolveImplicitLinkWithRedirect<Tail>(
        _ link:Link.Reference<Tail>, 
        namespace:Module.Index,
        arrival:Version?,
        nation:Package.Index, 
        keys:Route.Keys)
        -> Link.Resolution?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        guard let path:Path = .init(link)
        else 
        {
            return .one(.module(namespace))
        }
        guard let route:Route = keys[namespace, path, link.orientation]
        else 
        {
            return nil
        }
        // determine which package contains the actual symbol documentation; 
        // it may be different from the nation 
        let lens:Lexicon.Lens 
        if case let (culture, departure)? = link.query.lens, 
            let culture:Package = self[culture]
        {
            lens = .init(culture, at: departure)
        }
        else 
        {
            lens = .init(self[nation], at: arrival)
        }
        if  let resolution:Link.Resolution = .init(
            self.select(from: route, lens: lens, disambiguator: link.disambiguator))
        {
            return resolution
        }
        else if let route:Route = route.outed, 
            let resolution:Link.Resolution = .init(
            self.select(from: route, lens: lens, disambiguator: link.disambiguator))
        {
            return resolution
        }
        else 
        {
            return nil
        }
    }
}
extension Ecosystem
{
    private 
    func select(from route:Route, lexicon:Lexicon, disambiguator:Link.Disambiguator) 
        -> [Symbol.Composite]
    {
        self.select(from: route, lenses: lexicon.lenses)
        {
            lexicon.namespaces.contains($0.culture) && 
            self.filter($0, by: disambiguator)
        }
    }
    private 
    func select(from route:Route, lens:Lexicon.Lens, disambiguator:Link.Disambiguator) 
        -> [Symbol.Composite]
    {
        self.select(from: route, 
            lenses: CollectionOfOne<Lexicon.Lens>.init(lens), 
            disambiguator: disambiguator)
    }
    private 
    func select<Lenses>(from route:Route, lenses:Lenses, disambiguator:Link.Disambiguator) 
        -> [Symbol.Composite]
        where Lenses:Sequence, Lenses.Element == Lexicon.Lens
    {
        self.select(from: route, lenses: lenses)
        {
            self.filter($0, by: disambiguator)
        }
    }
    private 
    func select<Lenses>(from route:Route, lenses:Lenses, 
        where predicate:(Symbol.Composite) throws -> Bool) 
        rethrows -> [Symbol.Composite]
        where Lenses:Sequence, Lenses.Element == Lexicon.Lens
    {
        var matches:[Symbol.Composite] = []
        for lens:Lexicon.Lens in lenses 
        {
            switch lens.package.groups.table[route]
            {
            case nil, .none?: 
                continue 
            
            case .one(let composite)?:
                if try predicate(composite), lens.contains(composite)
                {
                    matches.append(composite)
                }
            
            case .many(let composites)?:
                for (base, diacritics):(Symbol.Index, Symbol.Subgroup) in composites 
                {
                    switch diacritics
                    {
                    case .none: 
                        continue  
                    case .one(let diacritic):
                        let composite:Symbol.Composite = .init(base, diacritic)
                        if try predicate(composite), lens.contains(composite)
                        {
                            matches.append(composite)
                        }
                    case .many(let diacritics):
                        for diacritic:Symbol.Diacritic in diacritics 
                        {
                            let composite:Symbol.Composite = .init(base, diacritic)
                            if try predicate(composite), lens.contains(composite)
                            {
                                matches.append(composite)
                            }
                        }
                    }
                }
            }
        }
        return matches
    }
    
    private 
    func filter(_ composite:Symbol.Composite, by disambiguator:Link.Disambiguator) 
        -> Bool
    {
        let symbol:Symbol = self[composite.base]
        switch disambiguator.suffix 
        {
        case nil: 
            break 
        case .fnv(_)?: 
            // TODO: implement this 
            break 
        case .color(symbol.color)?: 
            break 
        case .color(_)?:
            return false
        }
        if      let id:Symbol.ID = disambiguator.symbol, id != symbol.id 
        {
            return false
        }
        guard   let id:Symbol.ID = disambiguator.host
        else 
        {
            // nothing else we can use 
            return true 
        }
        if  let host:Symbol.Index = composite.host
        {
            return id == self[host].id
        }
        else 
        {
            return false 
        }
    }
}
