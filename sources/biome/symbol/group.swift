extension Symbol 
{
    struct Groups 
    {
        private(set)
        var table:[Route: Symbol.Group]
        
        init()
        {
            self.table = [:]
        }
        
        mutating 
        func insert(natural:(symbol:Symbol.Index, route:Route)) 
        {
            self.table[natural.route, default: .none].insert(.init(natural: natural.symbol))
        }
        mutating 
        func insert(perpetrator:Module.Index, 
            victim:(symbol:Symbol.Index, namespace:Module.Index, path:Route.Stem), 
            features:[(base:Symbol.Index, leaf:Route.Leaf)]) 
        {
            for (feature, leaf):(Symbol.Index, Route.Leaf) in features 
            {
                let route:Route = .init(victim.namespace, victim.path, leaf)
                let crime:Crime = .init(victim: victim.symbol, feature: feature, 
                    culture: perpetrator)
                self.table[route, default: .none].insert(crime)
            }
        }
        mutating 
        func merge(_ other:Self)
        {
            self.table.merge(other.table) { $0.union($1) }
        }
    }
    // 24B stride. the ``many`` case should be quite rare, since we are now 
    // encoding path orientation in the leaf key.
    enum Group 
    {
        // only used for dictionary initialization and array appends
        case none
        // if there is no feature index, the natural index is duplicated. 
        case one   (Crime)
        case many ([Crime])
        
        mutating 
        func insert(_ next:Crime)
        {
            switch self 
            {
            case .none: 
                self = .one(next)
            case .one(let first): 
                self = .many([first, next])
            case .many(var crimes):
                self = .none 
                crimes.append(next)
                self = .many(crimes)
            }
        }
        func union(_ other:Self) -> Self 
        {
            let union:Set<Crime>
            switch (self, other)
            {
            case (.none, .none): 
                return .none 
            case (.none, let some), (let some, .none):
                return some
            case (.one(let first), .one(let next)):
                return first == next ? .one(first) : .many([first, next])
            case (.many(let crimes), .one(let next)), (.one(let next), .many(let crimes)):
                union =  ([next] as Set<Crime>).union(crimes)
            case (.many(let crimes), .many(let others)):
                union = Set<Crime>.init(others).union(crimes)
            }
            if union.count <= 1 
            {
                fatalError("unreachable")
            }
            return .many([Crime].init(union))
        }
    }
}
