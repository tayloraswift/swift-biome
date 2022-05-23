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
    var filter:Set<Module.Index>
    private 
    var modules:[Module.ID: Module.Index], 
        symbols:[[Symbol.ID: Symbol.Index]]
    
    init()
    {
        self.filter = []
        self.symbols = [] 
        self.modules = [:] 
    }
    
    mutating 
    func `import`(_ module:Module)
    {
        self.filter.insert(module.index)
        self.modules[module.id] = module.index
    }
    mutating 
    func append(lens:[Symbol.ID: Symbol.Index])
    {
        self.symbols.append(lens)
    }
    
    func index(of symbol:Symbol.ID) throws -> Symbol.Index 
    {
        if let index:Symbol.Index = self[symbol]
        {
            return index 
        }
        else 
        {
            throw Symbol.ResolutionError.id(symbol)
        } 
    }
    subscript(module:Module.ID) -> Module.Index?
    {
        self.modules[module]
    }
    subscript(symbol:Symbol.ID) -> Symbol.Index?
    {
        var match:Symbol.Index? = nil
        for lens:[Symbol.ID: Symbol.Index] in self.symbols
        {
            guard let index:Symbol.Index = lens[symbol], 
                self.filter.contains(index.module)
            else 
            {
                continue 
            }
            if case nil = match 
            {
                match = index
            }
            else 
            {
                // sanity check: ensure none of the remaining lenses contains 
                // a colliding symbol 
                fatalError("colliding symbol identifiers in search space")
            }
        }
        return match
    }
}
