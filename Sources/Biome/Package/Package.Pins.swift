extension Package 
{
    struct Pins<Pin>
    {
        @available(*, deprecated)
        var version:Pin 
        {
            self.local 
        }
        
        let local:Pin
        let upstream:[Index: Version]
        
        init(local:Pin, upstream:[Index: Version])
        {
            self.local = local
            self.upstream = upstream
        }
        
        func isotropic(culture:Index) -> [Index: Version]
            where Pin == Version
        {
            var isotropic:[Index: Version] = self.upstream 
            isotropic[culture] = self.local 
            return isotropic
        }
    }
}
extension Package.Pins:Equatable where Pin:Equatable {}
extension Package.Pins:Sendable where Pin:Sendable {}
