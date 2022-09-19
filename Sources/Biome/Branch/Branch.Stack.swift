extension Branch 
{
    // 24B stride. the ``many`` case should be quite rare, since we are now 
    // encoding path orientation in the leaf key.
    enum Stack:Sendable 
    {
        // if there is no feature index, the natural index is duplicated. 
        case one ((Composite, Version.Revision))
        case many([Atom<Symbol>: Substack])
        
        @available(*, deprecated)
        func forEach(_ body:(Composite) throws -> ()) rethrows 
        {
            try self.forEach { (composite, _) in try body(composite) }
        }
        func forEach(_ body:(Composite, Version.Revision) throws -> ()) rethrows 
        {
            switch self
            {
            case .one((let composite, let revision)):
                try body(composite, revision)
            
            case .many(let composites):
                for (base, diacritics):(Atom<Symbol>, Substack) in composites 
                {
                    switch diacritics
                    {
                    case .one((let diacritic, let revision)):
                        try body(.init(base, diacritic), revision)
                    
                    case .many(let diacritics):
                        for (diacritic, revision):(Diacritic, Version.Revision) in diacritics
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
    func insert(_ element:Composite, revision:Version.Revision)
    {
        switch _move self
        {
        case nil: 
            self = .one((element, revision))
        case .one((element, let revision))?: 
            self = .one((element, revision)) 
        case .one(let other)?: 
            let two:[Atom<Symbol>: Branch.Substack]
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
    func remove(_ element:Composite)
    {
    }
}

extension Dictionary where Value == Branch.Stack 
{
    mutating 
    func stack(routes:some Sequence<(Key, Composite)>, revision:Version.Revision) 
    {
        for (key, composite):(Key, Composite) in routes 
        {
            self[key].insert(composite, revision: revision)
        }
    }

    func select(_ key:Key, _ body:(Composite) throws -> ()) rethrows 
    {
        try self[key]?.forEach { (composite, _) in try body(composite) }
    }
}
extension Divergences where Divergence == Branch.Stack
{
    func select(_ key:Key, _ body:(Composite) throws -> ()) rethrows 
    {
        try self[key]?.forEach 
        {
            if $1 <= self.limit 
            {
                try body($0)
            }
        }
    }
}
extension Sequence<Divergences<Route, Branch.Stack>>
{
    func select(_ key:Route, where predicate:(Composite) throws -> Bool) rethrows 
        -> _Selection<Composite>?
    {
        try self.select(key) { try predicate($0) ? $0 : nil }
    }
    func select<T>(_ key:Route, where filter:(Composite) throws -> T?) rethrows 
        -> _Selection<T>?
    {
        var selection:_Selection<T>? = nil
        try self.select(key) 
        {
            if let selected:T = try filter($0)
            {
                selection.append(selected)
            }
        } as ()
        return selection
    }
    func select(_ key:Route, _ body:(Composite) throws -> ()) rethrows 
    {
        for divergences:Divergences<Route, Branch.Stack> in self 
        {
            try divergences.select(key, body)
        }
    }
}
