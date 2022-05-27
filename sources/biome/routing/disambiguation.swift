extension Link 
{
    enum Resolution:Hashable 
    {
        case one(UniqueResolution)
        case many([UniqueResolution])
        
        init?(_ matches:[UniqueResolution]) 
        {
            guard let first:UniqueResolution = matches.first 
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
    }
    enum UniqueResolution:Hashable 
    {
        case package(Package.Index)
        case module(Module.Index)
        case symbol(Symbol.Index)
        case feature(Symbol.Index, Symbol.Index)
        
        static 
        func crime(_ crime:Crime) -> Self
        {
            if let victim:Symbol.Index = crime.victim
            {
                return .feature(victim, crime.base)
            }
            else 
            {
                return .symbol(crime.base)
            }
        }
    }
    struct Disambiguation 
    {
        let suffix:Suffix?
        let victim:Symbol.ID?
        let symbol:Symbol.ID?
    }
    /* enum DisambiguationError:Error 
    {
        case none 
        case many
    } */
}
extension Link.Disambiguation 
{
    func filter<Groups>(_ groups:Groups, 
        by dereference:(Symbol.Index) throws -> Symbol, 
        where predicate:(Module.Index) throws -> Bool = { _ in true }) 
        rethrows -> Link.Resolution?
        where Groups:Sequence, Groups.Element == Symbol.Group
    {
        var filtered:[Link.UniqueResolution] = []
        for group:Symbol.Group in groups 
        {
            switch group 
            {
            case .none: 
                break 
            case .one(let crime):
                if  try self.matches(crime, by: dereference, where: predicate)
                {
                    filtered.append(.crime(crime))
                }
            case .many(let crimes):
                for crime:Crime in crimes where 
                    try self.matches(crime, by: dereference, where: predicate)
                {
                    filtered.append(.crime(crime))
                }
            }
        }
        return .init(filtered)
    }
    private 
    func matches(_ crime:Crime, 
        by dereference:(Symbol.Index) throws -> Symbol, 
        where predicate:(Module.Index) throws -> Bool = { _ in true }) 
        rethrows -> Bool
    {
        guard try predicate(crime.culture)
        else 
        {
            return false 
        }
        let symbol:Symbol = try dereference(crime.base)
        switch self.suffix 
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
        if      let id:Symbol.ID = self.symbol, id != symbol.id 
        {
            return false
        }
        guard   let id:Symbol.ID = self.victim
        else 
        {
            // nothing else we can use 
            return true 
        }
        if  let victim:Symbol.Index = crime.victim
        {
            let victim:Symbol = try dereference(victim)
            return id == victim.id
        }
        else 
        {
            return false 
        }
    }
}
