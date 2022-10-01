import SymbolSource

struct Namespaces
{
    let id:ModuleIdentifier
    let module:Atom<Module>.Position
    var linked:[ModuleIdentifier: Atom<Module>.Position]

    init(_ module:Atom<Module>.Position, id:ModuleIdentifier)
    {
        self.linked = [id: module]
        self.module = module
        self.id = id 
    }

    var nationality:Packages.Index
    {
        self.culture.nationality
    }
    var culture:Atom<Module> 
    {
        self.module.atom
    }

    /// Returns a set containing all modules the current module depends on. 
    /// 
    /// This is similar to ``import``, except it excludes the current module.
    func dependencies() -> Set<Atom<Module>>
    {
        .init(self.linked.values.lazy.compactMap 
        { 
            $0.atom == self.culture ? nil : $0.atom 
        })
    }
    /// Returns a set containing all modules that can be imported, including the 
    /// current module.
    func `import`() -> Set<Atom<Module>>
    {
        .init(self.linked.values.lazy.map(\.atom))
    }
    
    /// Returns a set containing all modules that can be imported, among the requested 
    /// list of module names. The current module is always included in the set, 
    /// even if not explicitly requested.
    func `import`(_ modules:some Sequence<ModuleIdentifier>) -> Set<Atom<Module>>
    {
        var imported:Set<Atom<Module>> = []
            imported.reserveCapacity(modules.underestimatedCount + 1)
        for module:ModuleIdentifier in modules 
        {
            if let element:Atom<Module> = self.linked[module]?.atom
            {
                imported.insert(element)
            }
        }
        imported.insert(self.culture)
        return imported
    }
}

//  the endpoints of a graph edge can reference symbols in either this 
//  package or one of its dependencies. since imports are module-wise, and 
//  not package-wise, it’s possible for multiple index dictionaries to 
//  return matches, as long as only one of them belongs to an depended-upon module.
//  
//  it’s also possible to prefer a dictionary result in a foreign package over 
//  a dictionary result in the local package, if the foreign package contains 
//  a module that shadows one of the modules in the local package (as long 
//  as the target itself does not also depend upon the shadowed local module.)
struct ModuleUpdateContext
{
    let namespaces:Namespaces
    let upstream:[Packages.Index: Package.Pinned]
    let local:Fasces

    var nationality:Packages.Index
    {
        self.namespaces.nationality
    }
    var culture:Atom<Module> 
    {
        self.namespaces.culture
    }
    var id:ModuleIdentifier
    {
        self.namespaces.id
    }
    var module:Atom<Module>.Position
    {
        self.namespaces.module
    }
    var linked:[ModuleIdentifier: Atom<Module>.Position]
    {
        self.namespaces.linked
    }
}
