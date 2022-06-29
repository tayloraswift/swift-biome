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
    var orientation:Symbol.Link.Orientation 
    {
        self.bitPattern & 1 == 0 ? .gay : .straight
    }
    
    init(_ stem:Stem, orientation:Symbol.Link.Orientation) 
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
