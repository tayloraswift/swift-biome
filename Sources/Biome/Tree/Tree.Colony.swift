extension Tree 
{
    // this is like ``Symbol.IndexRange``, except the ``module`` field refers to 
    // a namespace, not the module that actually contains the symbol
    struct Colony:Hashable, Sendable
    {
        let namespace:Atom<Module> 
        let range:Range<Symbol.Offset>
        
        init(namespace:Atom<Module>, range:Range<Symbol.Offset>)
        {
            self.namespace = namespace
            self.range = range
        }
    }
}