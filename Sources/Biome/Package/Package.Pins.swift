extension Package 
{
    @usableFromInline
    struct Pins:Sendable
    {
        let local:(package:Index, version:Version)
        let upstream:[Index: Version]
        
        subscript(index:Index) -> Version? 
        {
            index == self.local.package ? self.local.version : self.upstream[index]
        }
        
        init(local:(package:Index, version:Version), upstream:[Index: Version])
        {
            self.local = local
            self.upstream = upstream
        }
    }
}
