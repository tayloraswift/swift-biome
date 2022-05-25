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
