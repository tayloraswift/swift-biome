import JSON

extension SymbolGraph 
{
    @frozen public 
    struct Dependency:Sendable
    {
        public
        var package:PackageIdentifier
        public
        var modules:[ModuleIdentifier]
        
        public 
        init(package:PackageIdentifier, modules:[ModuleIdentifier])
        {
            self.package = package 
            self.modules = modules 
        }
    }
}