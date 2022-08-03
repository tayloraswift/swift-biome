extension Symbol 
{
    enum Subgroup 
    {
        case one ((Diacritic, UInt16))
        case many([Diacritic: UInt16])
    }
    // 24B stride. the ``many`` case should be quite rare, since we are now 
    // encoding path orientation in the leaf key.
    enum Group 
    {
        // if there is no feature index, the natural index is duplicated. 
        case one ((Composite, UInt16))
        case many([Index: Subgroup])
                
        func forEach(_ body:(Composite) throws -> ()) rethrows 
        {
            switch self
            {
            case .one((let composite, _)):
                try body(composite)
            
            case .many(let composites):
                for (base, diacritics):(Index, Subgroup) in composites 
                {
                    switch diacritics
                    {
                    case .one((let diacritic, _)):
                        try body(.init(base, diacritic))
                    
                    case .many(let diacritics):
                        for diacritic:Diacritic in diacritics.keys 
                        {
                            try body(.init(base, diacritic))
                        }
                    }
                }
            }
        }
    }
}
extension Symbol.Group? 
{
    mutating 
    func insert(_ element:Symbol.Composite)
    {
        switch _move(self)
        {
        case nil: 
            self = .one((element, 1))
        case .one((element, let retains))?: 
            self = .one((element, retains + 1))
        case .one((let other, let retains))?: 
            let two:[Symbol.Index: Symbol.Subgroup]
            // overloading on host id is extremely rare; the column 
            // array layout is inefficient, but allows us to represent the 
            // more-common row layout efficiently
            if other.base == element.base 
            {
                two = 
                [
                    other.base: .many([other.diacritic: retains, element.diacritic: 1])
                ]
            }
            else 
            {
                two = 
                [
                    other.base: .one((other.diacritic, retains)), 
                    element.base: .one((element.diacritic, 1))
                ]
            }
            self = .many(two)
        
        case .many(var subgroups)?:
            subgroups[element.base].insert(element.diacritic)
            self = .many(subgroups)
        }
    }
    mutating 
    func remove(_ element:Symbol.Composite)
    {
        switch _move(self) 
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
        
        case .many(var subgroups)?: 
            subgroups[element.base].remove(element.diacritic)
            if subgroups.count > 1 
            {
                self = .many(subgroups)
                return 
            }
            switch subgroups.first 
            {
            case nil: 
                fatalError("unreachable, \(#function) should never remove more than one element at a time")
            case (let base, .one((let diacritic, let retains)))?:
                self = .one((.init(base, diacritic), retains))
            case (_, .many(_))?: 
                self = .many(subgroups)
            }
            return 
        }
        fatalError("cannot remove element from group it does not appear in")
    }
}
extension Symbol.Subgroup? 
{
    mutating 
    func insert(_ element:Symbol.Diacritic)
    {
        switch _move(self)
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
    func remove(_ element:Symbol.Diacritic)
    {
        switch _move(self)
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
            guard let index:Dictionary<Symbol.Diacritic, UInt16>.Index = 
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
                    diacritics.first.map(Symbol.Subgroup.one(_:))
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