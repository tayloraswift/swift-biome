extension Route 
{
    enum SelectionError<Element>:Error 
    {
        case many([Element])
    }
    enum _Selection<Element>
    {
        case one(Element)
        case many([Element])
                
        init?(_ elements:[Element]) 
        {
            if let first:Element = elements.first 
            {
                self = elements.count < 2 ? .one(first) : .many(elements)
            }
            else 
            {
                return nil
            }
        }
        
        func unique() throws -> Element
        {
            switch self 
            {
            case .one(let element):
                return element
            case .many(let elements): 
                throw SelectionError<Element>.many(elements)
            }
        }

        mutating 
        func append(_ element:Element) 
        {
            switch _move self 
            {
            case .one(let first): 
                self = .many([first, element])
            case .many(var elements): 
                elements.append(element)
                self = .many(elements)
            }
        }
    }
}

extension Route 
{
    // 24B stride. the ``many`` case should be quite rare, since we are now 
    // encoding path orientation in the leaf key.
    enum Stack:Sendable 
    {
        // if there is no feature index, the natural index is duplicated. 
        case one ((Branch.Composite, UInt16))
        case many([Branch.Position<Symbol>: Substack])
                
        func forEach(_ body:(Branch.Composite) throws -> ()) rethrows 
        {
            switch self
            {
            case .one((let composite, _)):
                try body(composite)
            
            case .many(let composites):
                for (base, diacritics):(Branch.Position<Symbol>, Substack) in composites 
                {
                    switch diacritics
                    {
                    case .one((let diacritic, _)):
                        try body(.init(base, diacritic))
                    
                    case .many(let diacritics):
                        for diacritic:Branch.Diacritic in diacritics.keys 
                        {
                            try body(.init(base, diacritic))
                        }
                    }
                }
            }
        }
    }
}
extension Route.Stack? 
{
    mutating 
    func insert(_ element:Branch.Composite)
    {
        switch _move self
        {
        case nil: 
            self = .one((element, 1))
        case .one((element, let retains))?: 
            self = .one((element, retains + 1))
        case .one((let other, let retains))?: 
            let two:[Branch.Position<Symbol>: Route.Substack]
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
    func remove(_ element:Branch.Composite)
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