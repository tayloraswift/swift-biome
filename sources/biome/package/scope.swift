extension Module 
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
    struct Scope
    {
        private 
        var namespaces:[ID: Index], 
            filter:Set<Index>
        let culture:Index
        
        init(culture:Index, id:ID)
        {
            self.namespaces = [id: culture]
            self.filter = [culture]
            self.culture = culture 
        }
        
        subscript(namespace:ID) -> Index?
        {
            _read 
            {
                yield self.namespaces[namespace]
            }
        }
        
        func contains(_ namespace:ID) -> Bool
        {
            self.namespaces.keys.contains(namespace)
        }
        func contains(_ namespace:Index) -> Bool
        {
            self.filter.contains(namespace)
        }
        
        mutating 
        func insert(namespace:Index, id:ID)
        {
            self.namespaces[id] = namespace
            self.filter.insert(namespace)
        }
        
        func packages() -> Set<Package.Index>
        {
            var packages:Set<Package.Index> = .init(self.filter.map(\.package))
                packages.remove(self.culture.package)
            return packages
        }
    }
}
extension Symbol 
{
    public
    struct Scope
    {
        public 
        struct ResolutionError:Error, Hashable 
        {
            var id:Symbol.ID 
            
            public 
            var description:String 
            {
                "could not resolve symbol '\(self.id.string)' (\(self.id.description))"
            }
        }
        
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
                throw ResolutionError.init(id: id)
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
