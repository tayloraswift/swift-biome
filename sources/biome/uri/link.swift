import Grammar

enum Link:Hashable, Sendable
{
    case target(Target, visible:Int)
    case fallback(String)
}
extension Link 
{
    enum Resolution
    {
        case one(Target)
        case many([Target])
        
        init?(_ matches:[Target]) 
        {
            guard let first:Target = matches.first 
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
    enum Target:Hashable 
    {
        case package(Package.Index)
        case module(Module.Index)
        case article(Article.Index)
        case composite(Symbol.Composite)
        
        static 
        func symbol(_ natural:Symbol.Index) -> Self 
        {
            .composite(.init(natural: natural))
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
    func filter(_ group:Symbol.Group, 
        by dereference:(Symbol.Index) throws -> Symbol, 
        where predicate:(Module.Index) throws -> Bool) 
        rethrows -> Link.Resolution?
    {
        let groups:CollectionOfOne<Symbol.Group> = .init(group)
        return try self.filter(groups, by: dereference, where: predicate)
    }
    func filter<Groups>(_ groups:Groups, 
        by dereference:(Symbol.Index) throws -> Symbol, 
        where predicate:(Module.Index) throws -> Bool) 
        rethrows -> Link.Resolution?
        where Groups:Sequence, Groups.Element == Symbol.Group
    {
        var filtered:[Link.Target] = []
        for group:Symbol.Group in groups 
        {
            switch group 
            {
            case .none: 
                break 
            case .one(let composite):
                if try self.matches(composite, by: dereference, where: predicate)
                {
                    filtered.append(.composite(composite))
                }
            case .many(let composites):
                for (base, diacritics):(Symbol.Index, Symbol.Subgroup) in composites 
                {
                    switch diacritics
                    {
                    case .none: 
                        break 
                    case .one(let diacritic):
                        let composite:Symbol.Composite = .init(base, diacritic)
                        if try self.matches(composite, by: dereference, where: predicate)
                        {
                            filtered.append(.composite(composite))
                        }
                    case .many(let diacritics):
                        for diacritic:Symbol.Diacritic in diacritics 
                        {
                            let composite:Symbol.Composite = .init(base, diacritic)
                            if try self.matches(composite, by: dereference, where: predicate)
                            {
                                filtered.append(.composite(composite))
                            }
                        }
                    }
                }
            }
        }
        return .init(filtered)
    }
    private 
    func matches(_ composite:Symbol.Composite, 
        by dereference:(Symbol.Index) throws -> Symbol, 
        where predicate:(Module.Index) throws -> Bool = { _ in true }) 
        rethrows -> Bool
    {
        guard try predicate(composite.culture)
        else 
        {
            return false 
        }
        let symbol:Symbol = try dereference(composite.base)
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
        if  let victim:Symbol.Index = composite.victim
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
