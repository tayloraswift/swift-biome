extension Ecosystem 
{
    private 
    func localize(nation:Package, arrival:Version, lens:(culture:Package.ID, version:Version?)?) 
        -> (package:Package, pins:Package.Pins)?
    {
        if case let (package, departure)? = lens 
        {
            if  let package:Package = self[package], 
                let pins:Package.Pins = package.versions[departure ?? package.latest]
            {
                return (package, pins)
            }
            else 
            {
                return nil
            }
        }
        else if let pins:Package.Pins = nation.versions[arrival]
        {
            return (nation, pins)
        }
        else 
        {
            return nil
        }
    }
    func resolve<Tail>(location global:Link.Reference<Tail>, keys:Route.Keys) 
        -> (selection:Selection, pins:Package.Pins, redirected:Bool)?
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
        let arrival:Version
        if let version:Version = local.arrival
        {
            qualified = _move(local).dropFirst()
            arrival = version 
        }
        else 
        {
            qualified = _move(local) 
            arrival = nation.latest
        }
        
        guard let namespace:Module.ID = qualified.namespace 
        else 
        {
            if explicit, let pins:Package.Pins = nation.versions[arrival]
            {
                return (.package(nation.index), pins, false) 
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
                return (.module(namespace), pins, false)
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
                lens: .init(localized.package, at: localized.pins.version), 
                disambiguator: implicit.disambiguator)
        {
            return (selection, localized.pins, redirected)
        }
        else 
        {
            return nil
        }
    }
    
    func resolve(link string:String, lexicon:Lexicon, imports:Set<Module.Index>, nest:Symbol.Nest?) 
        -> Link
    {
        // must attempt to parse absolute first, otherwise 
        // '/foo' will parse to ["", "foo"]
        let selection:Selection?
        let visible:Int
        if let absolute:Link.Expression = try? .init(absolute: string)
        {
            visible = absolute.visible
            selection = self.selectWithRedirect(globalLink: absolute.reference, 
                lexicon: lexicon)
        }
        else if let relative:Link.Expression = try? .init(relative: string)
        {
            visible = relative.visible
            selection = self.selectWithRedirect(visibleLink: relative.reference, 
                lexicon: lexicon,
                imports: imports, 
                nest: nest)
        }
        else 
        {
            print(self.describe(.none(string)))
            return .unresolved(string)
        }
        guard let selection:Selection = selection 
        else 
        {
            print(self.describe(.none(string)))
            return .unresolved(string)
        }
        guard let index:Index = selection.index 
        else 
        {
            print(self.describe(.many(string, selection.possibilities)))
            return .unresolved(string)
        }
        
        return .resolved(index, visible: visible)
    }
    func resolve(binding string:String, lexicon:Lexicon) -> Index?
    {
        if  let expression:Link.Expression = 
            try? Link.Expression.init(relative: string),
            let selection:Selection = 
            self.selectWithRedirect(visibleLink: expression.reference, lexicon: lexicon)
        {
            return selection.index
        }
        else 
        {
            return nil 
        }
    }
    
    private 
    func selectWithRedirect<Tail>(globalLink link:Link.Reference<Tail>, lexicon:Lexicon)
        -> Selection?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        guard   let nation:Package.ID = link.nation, 
                let nation:Package = self[nation]
        else 
        {
            return nil 
        }
        
        let qualified:Link.Reference<Tail.SubSequence> = link.dropFirst()
        
        guard let namespace:Module.ID = qualified.namespace 
        else 
        {
            return .package(nation.index)
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
            return .module(namespace)
        }
        guard let route:Route = lexicon.keys[namespace, path, implicit.orientation]
        else 
        {
            return nil
        }
        // if the global path starts with a package/namespace that 
        // matches one of our dependencies, treat it like a qualified 
        // reference. 
        if  case nil = implicit.query.lens, lexicon.namespaces.contains(namespace), 
            let selection:Selection = 
            self.selectWithRedirect(from: route, lexicon: lexicon, 
                disambiguator: implicit.disambiguator)
        {
            return selection
        }
        
        guard let localized:(package:Package, pins:Package.Pins) = 
            self.localize(nation: nation, arrival: nation.latest, lens: implicit.query.lens)
        else 
        {
            return nil
        }
        if case let (selection, _)? = self.selectWithRedirect(from: route, 
            lens: .init(localized.package, at: localized.pins.version), 
            disambiguator: implicit.disambiguator)
        {
            return selection
        }
        else 
        {
            return nil
        }
    } 
    private 
    func selectWithRedirect<Tail>(
        visibleLink link:Link.Reference<Tail>, 
        lexicon:Lexicon,
        imports:Set<Module.Index> = [], 
        nest:Symbol.Nest? = nil) 
        -> Selection?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        if  let selection:Selection = self.select(visibleLink: link, 
                lexicon: lexicon, 
                imports: imports, 
                nest: nest)
        {
            return selection 
        }
        else if let link:Link.Reference<Tail> = link.outed, 
            let selection:Selection = self.select(visibleLink: link, 
                lexicon: lexicon, 
                imports: imports, 
                nest: nest)
        {
            return selection
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
    func select<Tail>(visibleLink link:Link.Reference<Tail>, 
        lexicon:Lexicon,
        imports:Set<Module.Index> = [], 
        nest:Symbol.Nest? = nil) 
        -> Selection?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        if  let qualified:Selection = self.select(qualifiedLink: link, lexicon: lexicon)
        {
            return qualified
        }
        if  let nest:Symbol.Nest = nest, 
            lexicon.culture == nest.namespace || imports.contains(nest.namespace), 
            let relative:Selection = self.select(relativeLink: link, 
                namespace: nest.namespace, 
                prefix: nest.prefix, 
                lexicon: lexicon)
        {
            return relative
        }
        if  let absolute:Selection = self.select(relativeLink: link, 
                namespace: lexicon.culture, 
                lexicon: lexicon) 
        {
            return absolute
        }
        var imported:Selection? = nil 
        for namespace:Module.Index in imports where namespace != lexicon.culture 
        {
            if  let absolute:Selection = self.select(relativeLink: link, 
                    namespace: namespace, 
                    lexicon: lexicon) 
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
    func select<Tail>(qualifiedLink link:Link.Reference<Tail>, lexicon:Lexicon) 
        -> Selection?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        // check if the first component refers to a module. it can be the same 
        // as its own culture, or one of its dependencies. 
        
        // ``modulename/typename.membername(_:)``
        if  let namespace:Module.ID = link.namespace, 
            let namespace:Module.Index = lexicon.namespaces[namespace]
        {
            return self.select(relativeLink: link.dropFirst(), 
                namespace: namespace, 
                lexicon: lexicon)
        }
        else 
        {
            return nil
        }
    }
    private 
    func select<Tail>(
        relativeLink link:Link.Reference<Tail>, 
        namespace:Module.Index, 
        prefix:[String] = [], 
        lexicon:Lexicon) 
        -> Selection?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        guard let path:Path = .init(prefix, link)
        else 
        {
            return .module(namespace)
        }
        guard let route:Route = lexicon.keys[namespace, path, link.orientation]
        else 
        {
            return nil
        }
        return self.select(from: route, lexicon: lexicon, 
            disambiguator: link.disambiguator)
    }
}
extension Ecosystem
{
    private 
    func selectWithRedirect(from route:Route, lens:Package.Pinned, disambiguator:Link.Disambiguator) 
        -> (selection:Selection, redirected:Bool)?
    {
        if  let selection:Selection = 
            self.select(from: route, lens: lens, disambiguator: disambiguator)
        {
            return (selection, false)
        }
        else if let route:Route = route.outed, 
            let selection:Selection = 
            self.select(from: route, lens: lens, disambiguator: disambiguator)
        {
            return (selection, true)
        }
        else 
        {
            return nil
        }
    }
    private 
    func select(from route:Route, lens:Package.Pinned, disambiguator:Link.Disambiguator) 
        -> Selection?
    {
        self.select(from: route, lenses: CollectionOfOne<Package.Pinned>.init(lens))
        {
            self.filter($0, by: disambiguator)
        }
    }
    
    private 
    func selectWithRedirect(from route:Route, lexicon:Lexicon, disambiguator:Link.Disambiguator) 
        -> Selection?
    {
        if  let selection:Selection = 
            self.select(from: route, lexicon: lexicon, disambiguator: disambiguator)
        {
            return selection
        }
        else if let route:Route = route.outed, 
            let selection:Selection = 
            self.select(from: route, lexicon: lexicon, disambiguator: disambiguator)
        {
            return selection
        }
        else 
        {
            return nil
        }
    }
    private 
    func select(from route:Route, lexicon:Lexicon, disambiguator:Link.Disambiguator) 
        -> Selection?
    {
        self.select(from: route, lenses: lexicon.lenses)
        {
            lexicon.namespaces.contains($0.culture) && 
            self.filter($0, by: disambiguator)
        }
    }
    
    private 
    func select<Lenses>(from route:Route, lenses:Lenses, disambiguator:Link.Disambiguator) 
        -> Selection?
        where Lenses:Sequence, Lenses.Element == Package.Pinned
    {
        self.select(from: route, lenses: lenses)
        {
            self.filter($0, by: disambiguator)
        }
    }
    private 
    func select<Lenses>(from route:Route, lenses:Lenses, 
        where predicate:(Symbol.Composite) throws -> Bool) 
        rethrows -> Selection?
        where Lenses:Sequence, Lenses.Element == Package.Pinned
    {
        var matches:[Symbol.Composite] = []
        for pinned:Package.Pinned in lenses 
        {
            switch pinned.package.groups[route]
            {
            case .none: 
                continue 
            
            case .one(let composite):
                if try predicate(composite), pinned.contains(composite)
                {
                    matches.append(composite)
                }
            
            case .many(let composites):
                for (base, diacritics):(Symbol.Index, Symbol.Subgroup) in composites 
                {
                    switch diacritics
                    {
                    case .none: 
                        continue  
                    case .one(let diacritic):
                        let composite:Symbol.Composite = .init(base, diacritic)
                        if try predicate(composite), pinned.contains(composite)
                        {
                            matches.append(composite)
                        }
                    case .many(let diacritics):
                        for diacritic:Symbol.Diacritic in diacritics 
                        {
                            let composite:Symbol.Composite = .init(base, diacritic)
                            if try predicate(composite), pinned.contains(composite)
                            {
                                matches.append(composite)
                            }
                        }
                    }
                }
            }
        }
        return .init(matches)
    }
    
    private 
    func filter(_ composite:Symbol.Composite, by disambiguator:Link.Disambiguator) 
        -> Bool
    {
        let host:Symbol = self[composite.diacritic.host]
        let base:Symbol = self[composite.base]
        switch disambiguator.suffix 
        {
        case nil: 
            break 
        case .fnv(_)?: 
            // TODO: implement this 
            break 
        case .color(base.color)?: 
            break 
        case .color(_)?:
            return false
        }
        switch (disambiguator.base, disambiguator.host)
        {
        case    (base.id?, host.id?), 
                (base.id?, nil),
                (nil,      host.id?),
                (nil,      nil): 
            return true
        default: 
            return false
        }
    }
}
