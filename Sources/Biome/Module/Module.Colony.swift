extension Module 
{
    // this is like ``Symbol.IndexRange``, except the ``module`` field refers to 
    // a namespace, not the module that actually contains the symbol
    struct Colony:Hashable, Sendable
    {
        let namespace:Index 
        let range:Range<Symbol.Index.Offset>
        
        init(namespace:Index, range:Range<Symbol.Index.Offset>)
        {
            self.namespace = namespace
            self.range = range
        }
    }
}