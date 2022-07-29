import Versions 

@frozen public 
struct SwiftAvailability:Equatable, Sendable
{
    // unconditionals not allowed 
    public 
    var deprecated:MaskedVersion?
    public 
    var introduced:MaskedVersion?
    public 
    var obsoleted:MaskedVersion?
    public 
    var renamed:String?
    public 
    var message:String?
    
    @inlinable public 
    var isUsable:Bool 
    {
        if case _? = self.deprecated
        {
            return false 
        }
        if case _? = self.obsoleted 
        {
            return false 
        }
        else 
        {
            return true
        }
    }
    
    init(_ versioned:VersionedAvailability)
    {
        if case .since(let deprecated) = versioned.deprecated 
        {
            self.deprecated = deprecated
        }
        else 
        {
            self.deprecated = nil
        }
        self.introduced = versioned.introduced
        self.obsoleted = versioned.obsoleted
        self.renamed = versioned.renamed
        self.message = versioned.message
    }
}