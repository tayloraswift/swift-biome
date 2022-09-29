extension Package 
{
    @usableFromInline
    struct Pins:Sendable
    {
        let local:(package:Packages.Index, version:Version)
        let dependencies:[Packages.Index: Version]
        
        subscript(index:Packages.Index) -> Version? 
        {
            index == self.local.package ? self.local.version : self.dependencies[index]
        }
        
        init(local:(package:Packages.Index, version:Version), dependencies:[Packages.Index: Version])
        {
            self.local = local
            self.dependencies = dependencies
        }
    }
}
