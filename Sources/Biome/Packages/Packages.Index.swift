extension Packages 
{
    /// A globally-unique index referencing a package. 
    @frozen public 
    struct Index:Hashable, Comparable, Strideable, Sendable 
    {
        let offset:UInt16
        
        init(offset:UInt16)
        {
            self.offset = offset
        }

        public 
        func advanced(by stride:Int) -> Self 
        {
            .init(offset: self.offset.advanced(by: stride))
        }
        public 
        func distance(to other:Self) -> Int
        {
            self.offset.distance(to: other.offset)
        }
        public static 
        func < (lhs:Self, rhs:Self) -> Bool 
        {
            lhs.offset < rhs.offset
        }

        static 
        let swift:Self = .init(offset: 0)
        static 
        let core:Self = .init(offset: 1) 

        var isCommunityPackage:Bool
        {
            self.offset > 1
        }
    }
}