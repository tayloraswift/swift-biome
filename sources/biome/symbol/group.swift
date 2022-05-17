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
    // 24B stride. the ``many`` case should be quite rare, since we are now 
    // encoding path orientation in the leaf key.
    enum Group 
    {
        // only used for dictionary initialization and array appends
        case none
        // if there is no feature index, the natural index is duplicated. 
        case one   ((Index, Index))
        case many ([(Index, Index)])
        
        mutating 
        func insert(_ natural:Index)
        {
            self.insert((natural, natural))
        }
        mutating 
        func insert(_ victim:Index, feature:Index)
        {
            self.insert((victim, feature))
        }
        private mutating 
        func insert(_ next:(Index, Index))
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
    }
}
