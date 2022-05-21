extension Symbol 
{
    struct Key:Hashable 
    {
        // the lsb is reserved to encode orientation
        struct Stem:Hashable 
        {
            let bitPattern:UInt32
            
            var successor:Self 
            {
                .init(bitPattern: self.bitPattern + 2)
            }
        }
        struct Leaf:Hashable 
        {
            let bitPattern:UInt32 
            
            var stem:Stem 
            {
                .init(bitPattern: self.bitPattern & 0xffff_fffe)
            }
            var orientation:Orientation 
            {
                self.bitPattern & 1 == 0 ? .gay : .straight
            }
            
            init(_ stem:Stem, orientation:Orientation) 
            {
                switch orientation 
                {
                case .gay:      self.bitPattern = stem.bitPattern
                case .straight: self.bitPattern = stem.bitPattern | 1
                }
            }
        }
        
        let namespace:Module.Index
        let stem:Stem 
        let leaf:Leaf 
        
        init(_ namespace:Module.Index, _ stem:Stem, _ leaf:Leaf)
        {
            self.namespace = namespace
            self.stem = stem
            self.leaf = leaf
        }
    }
    struct Pair:Hashable 
    {
        private 
        let prefix:Index, 
            suffix:Index
        
        static 
        func natural(_ index:Index) -> Self 
        {
            .init(prefix: index, suffix: index)
        }
        static 
        func synthesized(_ victim:Index, _ feature:Index) -> Self 
        {
            .init(prefix: victim, suffix: feature)
        }
    }
    // 24B stride. the ``many`` case should be quite rare, since we are now 
    // encoding path orientation in the leaf key.
    enum Group 
    {
        // only used for dictionary initialization and array appends
        case none
        // if there is no feature index, the natural index is duplicated. 
        case one   (Pair)
        case many ([Pair])
        
        mutating 
        func insert(_ next:Pair)
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
            let union:Set<Pair>
            switch (self, other)
            {
            case (.none, .none): 
                return .none 
            case (.none, let some), (let some, .none):
                return some
            case (.one(let first), .one(let next)):
                return first == next ? .one(first) : .many([first, next])
            case (.many(let pairs), .one(let next)), (.one(let next), .many(let pairs)):
                union =  ([next] as Set).union(pairs)
            case (.many(let pairs), .many(let others)):
                union = Set.init(others).union(pairs)
            }
            if union.count <= 1 
            {
                fatalError("unreachable")
            }
            return .many([Pair].init(union))
        }
    }
}
