extension Package 
{
    struct _Pinned:Sendable 
    {
        let package:Package 
        let version:_Version
        let fasces:Fasces 
        
        init(_ package:Package, version:_Version)
        {
            self.package = package
            self.version = version
            self.fasces = self.package.tree.fasces(through: self.version)
        }
    }
}