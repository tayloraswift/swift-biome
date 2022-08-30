//  the endpoints of a graph edge can reference symbols in either this 
//  package or one of its dependencies. since imports are module-wise, and 
//  not package-wise, it’s possible for multiple index dictionaries to 
//  return matches, as long as only one of them belongs to an depended-upon module.
//  
//  it’s also possible to prefer a dictionary result in a foreign package over 
//  a dictionary result in the local package, if the foreign package contains 
//  a module that shadows one of the modules in the local package (as long 
//  as the target itself does not also depend upon the shadowed local module.)
struct Namespaces
{
    private 
    var indices:[Module.ID: Module.Index]
    private(set)
    var filter:Set<Module.Index>
    let origin:CulturalBuffer<Module>.Origin 

    var culture:Module.Index 
    {
        self.origin.index
    }
    
    subscript(namespace:Module.ID) -> Module.Index?
    {
        _read 
        {
            yield self.indices[namespace]
        }
    }
    
    private 
    init(origin:CulturalBuffer<Module>.Origin, indices:[Module.ID: Module.Index])
    {
        self.origin = origin 
        self.indices = indices 
        self.filter = .init(indices.values)
    }
    init(origin:CulturalBuffer<Module>.Origin, id:Module.ID)
    {
        self.init(origin: origin, indices: [id: origin.index])
    }
    
    mutating 
    func insert(_ namespace:Module.Index, id:Module.ID)
    {
        self.indices[id] = namespace
        self.filter.insert(namespace)
    }
    
    func contains(_ namespace:Module.ID) -> Bool
    {
        self.indices.keys.contains(namespace)
    }
    func contains(_ namespace:Module.Index) -> Bool
    {
        self.filter.contains(namespace)
    }
    
    func dependencies() -> Set<Module.Index>
    {
        var dependencies:Set<Module.Index> = self.filter 
            dependencies.remove(self.culture)
        return dependencies
    }
    
    func `import`(_ modules:Set<Module.ID>, swift:Package.Index?) -> Self 
    {
        .init(origin: self.origin, indices: self.indices.filter 
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

extension Module 
{
    //@available(*, deprecated, renamed: "Namespaces")
    typealias Scope = Namespaces
}
