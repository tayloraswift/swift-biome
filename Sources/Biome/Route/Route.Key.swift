@available(*, deprecated, renamed: "Route.Stem")
typealias Stem = Route.Stem 
@available(*, deprecated, renamed: "Route.Leaf")
typealias Leaf = Route.Leaf

extension Route 
{
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
    struct Key:Hashable, Sendable, CustomStringConvertible 
    {
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
        
        init(_ namespace:Module.Index, _ stem:Stem, _ leaf:Stem, orientation:Symbol.Link.Orientation)
        {
            self.init(namespace, stem, .init(leaf, orientation: orientation))
        }
        init(_ namespace:Module.Index, _ stem:Stem, _ leaf:Leaf)
        {
            self.namespace = namespace
            self.stem = stem
            self.leaf = leaf
        }
        
        func first<T>(where transform:(Self) throws -> T?) rethrows -> (T, redirected:Bool)? 
        {
            if      let result:T = try transform(self)
            {
                return (result, false)
            }
            else if let outed:Self = self.outed, 
                    let result:T = try transform(outed)
            {
                return (result, true)
            }
            else 
            {
                return nil
            }
        }
    }
}
