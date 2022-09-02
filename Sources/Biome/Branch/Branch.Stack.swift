extension Branch 
{
    enum SelectionError<Element>:Error 
    {
        case none
        case many([Element])
    }
    enum _Selection<Element>
    {
        // we have to absorb the optional, because this type is 
        // generic, and we cannot vend an extension on an optional generic type.

        case none 
        case one(Element)
        case many([Element])
                
        init(_ elements:[Element]) 
        {
            if let first:Element = elements.first 
            {
                self = elements.count < 2 ? .one(first) : .many(elements)
            }
            else 
            {
                self = .none
            }
        }
        
        func unique() throws -> Element
        {
            switch self 
            {
            case .none: 
                throw SelectionError<Element>.none
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
            case .none: 
                self = .one(element)
            case .one(let first): 
                self = .many([first, element])
            case .many(var elements): 
                elements.append(element)
                self = .many(elements)
            }
        }
    }
}

extension Branch 
{
    // 24B stride. the ``many`` case should be quite rare, since we are now 
    // encoding path orientation in the leaf key.
    enum Stack:Sendable 
    {
        // if there is no feature index, the natural index is duplicated. 
        case one ((Composite, _Version.Revision))
        case many([Position<Symbol>: Substack])
        
        @available(*, deprecated)
        func forEach(_ body:(Composite) throws -> ()) rethrows 
        {
            try self.forEach { (composite, _) in try body(composite) }
        }
        func forEach(_ body:(Composite, _Version.Revision) throws -> ()) rethrows 
        {
            switch self
            {
            case .one((let composite, let revision)):
                try body(composite, revision)
            
            case .many(let composites):
                for (base, diacritics):(Position<Symbol>, Substack) in composites 
                {
                    switch diacritics
                    {
                    case .one((let diacritic, let revision)):
                        try body(.init(base, diacritic), revision)
                    
                    case .many(let diacritics):
                        for (diacritic, revision):(Diacritic, _Version.Revision) in diacritics
                        {
                            try body(.init(base, diacritic), revision)
                        }
                    }
                }
            }
        }
    }
}
extension Branch.Stack? 
{
    mutating 
    func insert(_ element:Branch.Composite, revision:_Version.Revision)
    {
        switch _move self
        {
        case nil: 
            self = .one((element, revision))
        case .one((element, let revision))?: 
            self = .one((element, revision)) 
        case .one(let other)?: 
            let two:[Branch.Position<Symbol>: Branch.Substack]
            // overloading on host id is extremely rare; the column 
            // array layout is inefficient, but allows us to represent the 
            // more-common row layout efficiently
            if other.0.base == element.base 
            {
                two = 
                [
                    other.0.base: .many([other.0.diacritic: other.1, element.diacritic: revision])
                ]
            }
            else 
            {
                two = 
                [
                    other.0.base: .one((other.0.diacritic, other.1)), 
                    element.base: .one((element.diacritic, revision))
                ]
            }
            self = .many(two)
        
        case .many(var subgroups)?:
            subgroups[element.base].insert(element.diacritic, revision: revision)
            self = .many(subgroups)
        }
    }
    @available(*, unavailable)
    mutating 
    func remove(_ element:Branch.Composite)
    {
    }
}