extension Symbol 
{
    struct Groups 
    {
        private(set)
        var table:[Route: Group]
        
        init()
        {
            self.table = [:]
        }
        
        mutating 
        func insert(natural:Index, at route:Route)
        {
            self.table[route, default: .none].insert(.init(natural: natural))
        }
        mutating 
        func insert(diacritic:Diacritic, 
            features:[(base:Index, leaf:Route.Leaf)],
            under victim:(namespace:Module.Index, path:Route.Stem))
        {
            for (base, leaf):(Index, Route.Leaf) in features 
            {
                let route:Route = .init(victim.namespace, victim.path, leaf)
                self.table[route, default: .none].insert(.init(base, diacritic))
            }
        }
    }
    // 24B stride. the ``many`` case should be quite rare, since we are now 
    // encoding path orientation in the leaf key.
    enum Group 
    {
        // only used for dictionary initialization and array appends
        case none
        // if there is no feature index, the natural index is duplicated. 
        case one   (Composite)
        case many ([Index: Subgroup])
        
        mutating 
        func insert(_ next:Composite)
        {
            switch self 
            {
            case .none: 
                self = .one(next)
            case .one(next): 
                break
            case .one(let first): 
                let two:[Index: Subgroup]
                // overloading on victim id is extremely rare; the column 
                // array layout is inefficient, but allows us to represent the 
                // more-common row layout efficiently
                if first.base == next.base 
                {
                    two = [first.base: .many([first.diacritic, next.diacritic])]
                }
                else 
                {
                    two = [first.base: .one(first.diacritic), next.base: .one(next.diacritic)]
                }
                self = .many(two)
            
            case .many(var subgroups):
                self = .none 
                subgroups[next.base, default: .none].insert(next.diacritic)
                self = .many(subgroups)
            }
        }
    }
    enum Subgroup 
    {
        case none 
        
        case one     (Diacritic)
        case many(Set<Diacritic>)
        
        mutating 
        func insert(_ next:Diacritic)
        {
            switch self 
            {
            case .none: 
                self = .one(next)
            case .one(next): 
                break
            case .one(let first): 
                self = .many([first, next])
            case .many(var diacritics):
                self = .none 
                diacritics.insert(next)
                self = .many(diacritics)
            }
        }
    }
}
