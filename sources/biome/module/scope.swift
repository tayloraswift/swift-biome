extension Module 
{
    struct Scope 
    {
        //  the endpoints of a graph edge can reference symbols in either this 
        //  package or one of its dependencies. since imports are module-wise, and 
        //  not package-wise, it’s possible for multiple index dictionaries to 
        //  return matches, as long as only one of them belongs to an depended-upon module.
        //  
        //  it’s also possible to prefer a dictionary result in a foreign package over 
        //  a dictionary result in the local package, if the foreign package contains 
        //  a module that shadows one of the modules in the local package (as long 
        //  as the target itself does not also depend upon the shadowed local module.)
        private 
        let filter:Set<Module.Index>
        private 
        let layers:[[Symbol.ID: Symbol.Index]]
        
        init(filter:Set<Module.Index>, layers:[[Symbol.ID: Symbol.Index]])
        {
            self.filter = filter 
            self.layers = layers 
        }
        
        func index(of symbol:Symbol.ID) throws -> Symbol.Index 
        {
            if let index:Symbol.Index = self[symbol]
            {
                return index 
            }
            else 
            {
                throw Symbol.ResolutionError.undefined(symbol)
            } 
        }
        private 
        subscript(symbol:Symbol.ID) -> Symbol.Index?
        {
            for layer:Int in self.layers.indices
            {
                guard let index:Symbol.Index = self.layers[layer][symbol], 
                    self.filter.contains(index.module)
                else 
                {
                    continue 
                }
                // sanity check: ensure none of the remaining layers contains 
                // a colliding symbol 
                for layer:[Symbol.ID: Symbol.Index] in self.layers[layer...].dropFirst()
                {
                    if case _? = layer[symbol], self.filter.contains(index.module)
                    {
                        fatalError("colliding symbol identifiers in search space")
                    }
                }
                return index
            }
            return nil
        }
    }
}
