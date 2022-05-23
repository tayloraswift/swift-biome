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
}
