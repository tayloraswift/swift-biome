extension Ecosystem 
{
    enum Selection
    {
        case package(Package.Index)
        case module(Module.Index)
        case article(Article.Index)
        case composite(Symbol.Composite)
        case composites([Symbol.Composite])
        
        var index:Index?
        {
            switch self 
            {
            case .package   (let index):    return .package     (index)
            case .module    (let index):    return .module      (index)
            case .article   (let index):    return .article     (index)
            case .composite (let index):    return .composite   (index)
            case .composites(_):            return nil
            }
        }
        var possibilities:[Symbol.Composite] 
        {
            if case .composites(let possibilities) = self
            {
                return possibilities
            }
            else 
            {
                return []
            }
        }
        
        init?(_ matches:[Symbol.Composite]) 
        {
            guard let first:Symbol.Composite = matches.first 
            else 
            {
                return nil
            }
            if matches.count < 2
            {
                self = .composite(first)
            } 
            else 
            {
                self = .composites(matches)
            }
        }
    }
    
    func localize(nation:Package, 
        arrival:MaskedVersion?, 
        lens:(culture:Package.ID, version:MaskedVersion?)?) 
        -> (package:Package, pins:Package.Pins)?
    {
        if case let (package, departure)? = lens 
        {
            if  let package:Package = self[package], 
                let pins:Package.Pins = package.versions[departure]
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
            self.selectWithRedirect(from: route, in: lexicon, by: implicit.disambiguator)
        {
            return selection
        }
        
        guard let localized:(package:Package, pins:Package.Pins) = 
            self.localize(nation: nation, arrival: nil, lens: implicit.query.lens)
        else 
        {
            return nil
        }
        if case let (selection, _)? = self.selectWithRedirect(from: route, 
            in: .init(localized.package, at: localized.pins.version), 
            by: implicit.disambiguator)
        {
            return selection
        }
        else 
        {
            return nil
        }
    } 
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
        return self.select(from: route, in: lexicon, by: link.disambiguator)
    }
}
extension Ecosystem
{
    func selectWithRedirect(from route:Route, in pinned:Package.Pinned, 
        by disambiguator:Link.Disambiguator) 
        -> (selection:Selection, redirected:Bool)?
    {
        if  let selection:Selection = 
            self.select(from: route, in: pinned, by: disambiguator)
        {
            return (selection, false)
        }
        else if let route:Route = route.outed, 
            let selection:Selection = 
            self.select(from: route, in: pinned, by: disambiguator)
        {
            return (selection, true)
        }
        else 
        {
            return nil
        }
    }
    private 
    func select(from route:Route, in pinned:Package.Pinned, 
        by disambiguator:Link.Disambiguator) 
        -> Selection?
    {
        self.select(from: route, in: CollectionOfOne<Package.Pinned>.init(pinned))
        {
            self.filter($0, by: disambiguator)
        }
    }
    
    private 
    func selectWithRedirect(from route:Route, in lexicon:Lexicon, 
        by disambiguator:Link.Disambiguator) 
        -> Selection?
    {
        if  let selection:Selection = 
            self.select(from: route, in: lexicon, by: disambiguator)
        {
            return selection
        }
        else if let route:Route = route.outed, 
            let selection:Selection = 
            self.select(from: route, in: lexicon, by: disambiguator)
        {
            return selection
        }
        else 
        {
            return nil
        }
    }
    private 
    func select(from route:Route, in lexicon:Lexicon, 
        by disambiguator:Link.Disambiguator) 
        -> Selection?
    {
        self.select(from: route, in: lexicon.lenses)
        {
            lexicon.namespaces.contains($0.culture) && 
            self.filter($0, by: disambiguator)
        }
    }
    
    private 
    func select<Lenses>(from route:Route, in lenses:Lenses, 
        by disambiguator:Link.Disambiguator) 
        -> Selection?
        where Lenses:Sequence, Lenses.Element == Package.Pinned
    {
        self.select(from: route, in: lenses)
        {
            self.filter($0, by: disambiguator)
        }
    }
    private 
    func select<Lenses>(from route:Route, in lenses:Lenses, 
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
