extension Route 
{
    enum Substack:Sendable 
    {
        case one ((Branch.Diacritic, UInt16))
        case many([Branch.Diacritic: UInt16])
    }
}

extension Route.Substack? 
{
    mutating 
    func insert(_ element:Branch.Diacritic)
    {
        switch _move self
        {
        case nil: 
            self = .one((element, 1))
        case .one((element, let retains))?: 
            self = .one((element, retains + 1))
        case .one((let other, let retains))?: 
            self = .many([other: retains, element: 1])
        case .many(var diacritics)?:
            diacritics[element, default: 0] += 1
            self = .many(diacritics)
        }
    }
    mutating 
    func remove(_ element:Branch.Diacritic)
    {
        switch _move self
        {
        case nil: 
            break 
        case .one((let occupant, let retains))?: 
            guard element == occupant 
            else 
            {
                break
            }
            self = retains == 1 ? nil : .one((element, retains - 1))
            return 

        case .many(var diacritics)?: 
            guard let index:Dictionary<Branch.Diacritic, UInt16>.Index = 
                diacritics.index(forKey: element)
            else 
            {
                break 
            }

            let retains:UInt16 = diacritics.values[index]
            if  retains == 1 
            {
                diacritics.remove(at: index)
                self = diacritics.count > 1 ? .many(diacritics) : 
                    diacritics.first.map(Wrapped.one(_:))
            }
            else 
            {
                diacritics.values[index] = retains - 1
                self = .many(diacritics)
            }
            return 
        }
        fatalError("cannot remove element from subgroup it does not appear in")
    }
}