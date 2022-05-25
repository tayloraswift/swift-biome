extension Symbol 
{
    // 24B stride. the ``many`` case should be quite rare, since we are now 
    // encoding path orientation in the leaf key.
    enum Group 
    {
        // only used for dictionary initialization and array appends
        case none
        // if there is no feature index, the natural index is duplicated. 
        case one   (IndexPair)
        case many ([IndexPair])
        
        mutating 
        func insert(_ next:IndexPair)
        {
            switch self 
            {
            case .none: 
                self = .one(next)
            case .one(let first): 
                self = .many([first, next])
            case .many(var pairs):
                self = .none 
                pairs.append(next)
                self = .many(pairs)
            }
        }
        func union(_ other:Self) -> Self 
        {
            let union:Set<IndexPair>
            switch (self, other)
            {
            case (.none, .none): 
                return .none 
            case (.none, let some), (let some, .none):
                return some
            case (.one(let first), .one(let next)):
                return first == next ? .one(first) : .many([first, next])
            case (.many(let pairs), .one(let next)), (.one(let next), .many(let pairs)):
                union =  ([next] as Set<IndexPair>).union(pairs)
            case (.many(let pairs), .many(let others)):
                union = Set<IndexPair>.init(others).union(pairs)
            }
            if union.count <= 1 
            {
                fatalError("unreachable")
            }
            return .many([IndexPair].init(union))
        }
    }
}
