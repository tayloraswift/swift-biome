extension Package 
{
    @usableFromInline
    struct Pins:Sendable
    {
        let local:(package:Index, version:Version)
        let dependencies:[Index: Version]
        
        subscript(index:Index) -> Version? 
        {
            index == self.local.package ? self.local.version : self.dependencies[index]
        }
        
        init(local:(package:Index, version:Version), dependencies:[Index: Version])
        {
            self.local = local
            self.dependencies = dependencies
        }
    }
}
