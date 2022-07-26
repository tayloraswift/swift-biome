import Versions 

@frozen public 
struct VersionedAvailability:Equatable, Sendable 
{
    @frozen public 
    enum Deprecation:Hashable, Sendable
    {
        case always
        case since(MaskedVersion)
    }
    public 
    var unavailable:Bool 
    // .some(nil) represents unconditional deprecation
    public 
    var deprecated:Deprecation?
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
        if case .always? = self.deprecated 
        {
            return true 
        }
        else 
        {
            return false 
        }
    }
}
