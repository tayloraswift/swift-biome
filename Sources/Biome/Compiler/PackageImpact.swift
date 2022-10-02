struct PackageImpact
{
    let dependencies:[Packages.Index: (version:Version, consumers:Set<Atom<Module>>)]
    let version:Version

    init(interface:PackageInterface)
    {
        self.version = interface.version 
        self.dependencies = interface.reduce(into: [:]) 
        { 
            for dependency:Packages.Index in $1.context.upstream.keys 
            {
                $0[dependency, default: (interface.version, [])].consumers.insert($1.culture)
            }
        }
    }
}