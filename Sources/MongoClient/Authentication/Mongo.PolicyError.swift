extension Mongo
{
    public
    enum PolicyError:Equatable, Error
    {
        case sha256Iterations(Int)
        case serverSignature
    }
}
extension Mongo.PolicyError:CustomStringConvertible
{
    public
    var description:String
    {
        switch self
        {
        case .sha256Iterations(let iterations):
            return 
                """
                security policy prohibits connecting to server with SCRAM-SHA-256 \
                iteration count set to '\(iterations)'
                """
        case .serverSignature:
            return 
                """
                security policy prohibits connecting to server that failed SCRAM \
                authentication
                """
        }
    }
}
