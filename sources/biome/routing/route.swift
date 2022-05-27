struct Route:Hashable, Sendable, CustomStringConvertible 
{
    enum Orientation:Unicode.Scalar
    {
        case gay        = "."
        case straight   = "/"
    }
    // the lsb is reserved to encode orientation
    struct Stem:Hashable 
    {
        private(set)
        var bitPattern:UInt32
        
        init()
        {
            self.bitPattern = 0
        }
        init(masking bits:UInt32)
        {
            self.bitPattern = bits & 0xffff_fffe
        }
        
        mutating 
        func increment() -> Self
        {
            self.bitPattern += 2 
            return self 
        }
    }
    struct Leaf:Hashable 
    {
        let bitPattern:UInt32 
        
        var stem:Stem 
        {
            .init(masking: self.bitPattern)
        }
        var outed:Self? 
        {
            let outed:Self = .init(bitPattern: self.stem.bitPattern)
            return outed == self ? nil : outed
        }
        var orientation:Orientation 
        {
            self.bitPattern & 1 == 0 ? .gay : .straight
        }
        
        init(_ stem:Stem, orientation:Orientation) 
        {
            switch orientation 
            {
            case .gay:      self.init(bitPattern: stem.bitPattern)
            case .straight: self.init(bitPattern: stem.bitPattern | 1)
            }
        }
        private 
        init(bitPattern:UInt32)
        {
            self.bitPattern = bitPattern
        }
    }
    
    let namespace:Module.Index
    let stem:Stem 
    let leaf:Leaf 
    
    var outed:Self? 
    {
        self.leaf.outed.map { .init(self.namespace, self.stem, $0) }
    }
    
    var description:String 
    {
        """
        \(self.namespace.package.bits):\
        \(self.namespace.bits).\
        \(self.stem.bitPattern >> 1).\
        \(self.leaf.bitPattern)
        """
    }
    
    init(_ namespace:Module.Index, _ stem:Stem, _ leaf:Stem, orientation:Orientation)
    {
        self.init(namespace, stem, .init(leaf, orientation: orientation))
    }
    init(_ namespace:Module.Index, _ stem:Stem, _ leaf:Leaf)
    {
        self.namespace = namespace
        self.stem = stem
        self.leaf = leaf
    }
}
