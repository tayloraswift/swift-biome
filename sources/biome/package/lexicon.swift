struct Lexicon
{
    struct Lens:Sendable 
    {
        let package:Package 
        let version:Version
        
        init(_ package:Package, at version:Version? = nil)
        {
            self.version = version ?? package.latest 
            self.package = package
        }
        
        func contains(_ composite:Symbol.Composite) -> Bool 
        {
            self.package.contains(composite, at: self.version)
        }
    }
    
    var namespaces:Module.Scope
    var lenses:[Lens]
    let keys:Route.Keys
    
    var culture:Module.Index 
    {
        self.namespaces.culture
    }
    
    init(keys:Route.Keys, namespaces:Module.Scope, lenses:[Lens])
    {
        self.namespaces = namespaces
        self.lenses = lenses
        self.keys = keys 
    }
    
    func resolve<Modules>(imports modules:Modules) -> [Module.Index]
        where Modules:Sequence, Modules.Element == Module.ID
    {
        modules.compactMap { self.namespaces[$0] }
    }
}
