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
        var namespaces:[ID: Index]
        private(set)
        var filter:Set<Index>
        let culture:Index
        
        subscript(namespace:ID) -> Index?
        {
            _read 
            {
                yield self.namespaces[namespace]
            }
        }
        
        private 
        init(culture:Index, namespaces:[ID: Index])
        {
            self.culture = culture 
            self.namespaces = namespaces 
            self.filter = .init(namespaces.values)
        }
        init(culture:Index, id:ID)
        {
            self.init(culture: culture, namespaces: [id: culture])
        }
        
        mutating 
        func insert(namespace:Index, id:ID)
        {
            self.namespaces[id] = namespace
            self.filter.insert(namespace)
        }
        
        func contains(_ namespace:ID) -> Bool
        {
            self.namespaces.keys.contains(namespace)
        }
        func contains(_ namespace:Index) -> Bool
        {
            self.filter.contains(namespace)
        }
        
        func upstream() -> Set<Package.Index>
        {
            var packages:Set<Package.Index> = .init(self.filter.map(\.package))
                packages.remove(self.culture.package)
            return packages
        }
        
        func `import`(_ modules:Set<ID>, swift:Package.Index?) -> Self 
        {
            .init(culture: self.culture, namespaces: self.namespaces.filter 
            {
                if case $0.value.package? = swift
                {
                    return true 
                }
                else if $0.value == self.culture
                {
                    return true 
                }
                else 
                {
                    return modules.contains($0.key)
                }
            })
        }
    }
}
