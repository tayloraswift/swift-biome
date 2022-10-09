import SymbolSource

@frozen public 
struct PackageDependency:Equatable, Sendable
{
    public
    var package:PackageIdentifier
    public
    var modules:[ModuleIdentifier]
    
    init(package:PackageIdentifier, sortedModules:[ModuleIdentifier])
    {
        self.package = package 
        self.modules = sortedModules
    }
    public 
    init(package:PackageIdentifier, modules:[ModuleIdentifier])
    {
        self.init(package: package, sortedModules: modules.sorted())
    }
}
