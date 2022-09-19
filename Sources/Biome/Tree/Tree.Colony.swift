extension Tree 
{
    // this is like ``Symbol.IndexRange``, except the ``module`` field refers to 
    // a namespace, not the module that actually contains the symbol
    struct Colony:Hashable, Sendable
    {
        let namespace:Position<Module> 
        let range:Range<Symbol.Offset>
        
        init(namespace:Position<Module>, range:Range<Symbol.Offset>)
        {
            self.namespace = namespace
            self.range = range
        }
    }
}