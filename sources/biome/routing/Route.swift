struct Route:Hashable, Sendable, CustomStringConvertible 
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
}
