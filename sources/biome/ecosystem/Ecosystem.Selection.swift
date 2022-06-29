extension Ecosystem 
{
    enum Selection
    {
        case index(Index)
        case composites([Symbol.Composite])
        
        static 
        func package(_ package:Package.Index) -> Self 
        {
            .index(.package(package))
        }
        static 
        func module(_ module:Module.Index) -> Self 
        {
            .index(.module(module))
        }
        static 
        func article(_ article:Article.Index) -> Self 
        {
            .index(.article(article))
        }
        static 
        func composite(_ composite:Symbol.Composite) -> Self 
        {
            .index(.composite(composite))
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
    
    func localize(destination:Package.Index, arrival:MaskedVersion? = nil,
        lens:(culture:Package.ID, version:MaskedVersion?)?) 
        -> (package:Package, pins:Package.Pins<Version>)?
    {
        if case let (package, departure)? = lens 
        {
            if  let package:Package = self[package], 
                let pins:Package.Pins<Version> = package.versions[departure]
            {
                return (package, pins)
            }
            else 
            {
                return nil
            }
        }
        else if let pins:Package.Pins<Version> = self[destination].versions[arrival]
        {
            return (self[destination], pins)
        }
        else 
        {
            return nil
        }
    }
}

extension Ecosystem
{
    func selectWithRedirect(from route:Route, lens:Package.Pinned, 
        by disambiguator:Symbol.Disambiguator) 
        -> (selection:Selection, redirected:Bool)?
    {
        if  let selection:Selection = 
            self.select(from: route, lens: lens, by: disambiguator)
        {
            return (selection, false)
        }
        else if let route:Route = route.outed, 
            let selection:Selection = 
            self.select(from: route, lens: lens, by: disambiguator)
        {
            return (selection, true)
        }
        else 
        {
            return nil
        }
    }
    private 
    func select(from route:Route, lens:Package.Pinned, 
        by disambiguator:Symbol.Disambiguator) 
        -> Selection?
    {
        self.select(from: route, lenses: CollectionOfOne<Package.Pinned>.init(lens))
        {
            self.filter($0, by: disambiguator)
        }
    }
    
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
    
    func filter(_ composite:Symbol.Composite, by disambiguator:Symbol.Disambiguator) 
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
