extension Mongo
{
    public
    enum AuthenticationError:Error
    {
        case sha256Iterations(Int)
        case conversationIncomplete
    }
}
extension Mongo.AuthenticationError:CustomStringConvertible
{
    public
    var description:String
    {
        switch self
        {
        case .sha256Iterations(let iterations):
            return "authentication policy prohibits SCRAM-SHA-256 iteration count of \(iterations)"
        
        case .conversationIncomplete:
            return "authentication conversation incomplete"
        }
    }
}
