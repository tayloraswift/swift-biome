extension Ecosystem 
{
    @usableFromInline
    enum Selection
    {
        case one(Symbol.Composite)
        case many([Symbol.Composite])
                
        init?(_ matches:[Symbol.Composite]) 
        {
            guard let first:Symbol.Composite = matches.first 
            else 
            {
                return nil
            }
            if matches.count < 2
            {
                self = .one(first)
            } 
            else 
            {
                self = .many(matches)
            }
        }
        
        func composite() throws -> Symbol.Composite 
        {
            switch self 
            {
            case .one(let composite):
                return composite 
            case .many(let composites): 
                throw SelectionError.many(composites)
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
    func selectExtantWithRedirect(from route:Route, lens:Package.Pinned, 
        by disambiguator:Symbol.Disambiguator) 
        -> (selection:Selection, redirected:Bool)?
    {
        route.first 
        {
            self.selectExtant(from: $0, lenses: CollectionOfOne<Package.Pinned>.init(lens))
            {
                self.filter($0, by: disambiguator)
            }
        }
    }
    func selectExtant<Lenses>(from route:Route, lenses:Lenses, 
        where predicate:(Symbol.Composite) throws -> Bool) 
        rethrows -> Selection?
        where Lenses:Sequence, Lenses.Element == Package.Pinned
    {
        var matches:[Symbol.Composite] = []
        for pinned:Package.Pinned in lenses 
        {
            try pinned.package.groups[route].forEach 
            {
                if try predicate($0), pinned.contains($0)
                {
                    matches.append($0)
                }
            }
        }
        return .init(matches)
    }
    
    func selectHistoricalWithRedirect(from route:Route, lens:Package, 
        by disambiguator:Symbol.Disambiguator) 
        -> (selection:Selection, redirected:Bool)?
    {
        route.first 
        {
            self.selectHistorical(from: $0, lens: lens)
            {
                self.filter($0, by: disambiguator)
            }
        }
    }
    private
    func selectHistorical(from route:Route, lens:Package, 
        where predicate:(Symbol.Composite) throws -> Bool) 
        rethrows -> Selection?
    {
        var matches:[Symbol.Composite] = []
        try lens.groups[route].forEach 
        {
            if try predicate($0)
            {
                matches.append($0)
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
