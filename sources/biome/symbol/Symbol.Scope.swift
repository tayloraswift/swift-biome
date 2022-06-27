extension Symbol 
{
    public 
    struct ScopeResolutionError:Error, Hashable 
    {
        var id:Symbol.ID 
        
        public 
        var description:String 
        {
            "could not resolve symbol '\(self.id.string)' (\(self.id.description))"
        }
    }
    
    struct Scope
    {
        var culture:Module.Index 
        {
            self.namespaces.culture
        }
        
        var namespaces:Module.Scope
        var lenses:[[Symbol.ID: Symbol.Index]]
        
        init(namespaces:Module.Scope, lenses:[[Symbol.ID: Symbol.Index]] = [])
        {
            self.namespaces = namespaces
            self.lenses = lenses
        }
        
        func index(of id:Symbol.ID) throws -> Symbol.Index 
        {
            if let index:Symbol.Index = self.find(id)
            {
                return index 
            }
            else 
            {
                throw ScopeResolutionError.init(id: id)
            } 
        }
        func contains(_ id:Symbol.ID) -> Bool
        {
            for lens:[Symbol.ID: Symbol.Index] in self.lenses
            {
                if let index:Symbol.Index = lens[id], self.namespaces.contains(index.module)
                {
                    return true  
                }
            }
            return false
        }
        func find(_ id:Symbol.ID) -> Symbol.Index?
        {
            var match:Symbol.Index? = nil
            for lens:[Symbol.ID: Symbol.Index] in self.lenses
            {
                guard let index:Symbol.Index = lens[id], self.namespaces.contains(index.module)
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
                    // a colliding key 
                    fatalError("colliding symbol identifiers in search space")
                }
            }
            return match
        }
    }
}
