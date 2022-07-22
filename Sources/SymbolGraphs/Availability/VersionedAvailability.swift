import Versions 

@frozen public 
struct VersionedAvailability:Equatable, Sendable 
{
    public 
    var unavailable:Bool 
    // .some(nil) represents unconditional deprecation
    public 
    var deprecated:MaskedVersion??
    public 
    var introduced:MaskedVersion?
    public 
    var obsoleted:MaskedVersion?
    public 
    var renamed:String?
    public 
    var message:String?
    
    @inlinable public 
    var isGenerallyDeprecated:Bool 
    {
        if case .some(nil) = self.deprecated 
        {
            return true 
        }
        else 
        {
            return false 
        }
    }
}
