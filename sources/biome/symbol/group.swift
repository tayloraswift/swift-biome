extension Symbol 
{
    struct Key:Hashable 
    {
        // the lsb is reserved to encode orientation
        struct Component:Hashable 
        {
            let bitPattern:UInt32
            
            var successor:Self 
            {
                .init(bitPattern: self.bitPattern + 2)
            }
        }
        
        let namespace:Module.Index
        let stem:Component 
        let leaf:UInt32 

        var orientation:Orientation 
        {
            self.leaf & 1 == 0 ? .gay : .straight
        }
        
        init(_ namespace:Module.Index, stem:Component, leaf:Component, orientation:Orientation)
        {
            switch orientation 
            {
            case .gay:      self.init(namespace, stem: stem, leaf: leaf.bitPattern)
            case .straight: self.init(namespace, stem: stem, leaf: leaf.bitPattern | 1)
            }
        }
        private 
        init(_ namespace:Module.Index, stem:Component, leaf:UInt32)
        {
            self.leaf = leaf
            self.stem = stem
            self.namespace = namespace
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
        func insert(natural:Index)
        {
            self.insert((natural, natural))
        }
        mutating 
        func insert(victim:Index, feature:Index)
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
