extension Mongo
{
    /// A namespace for SASL (Simple Authentication and Security Layer) types.
    public
    enum SASL:String, Hashable, Sendable 
    {
        case aws        = "MONGODB-AWS"
        case gssapi     = "GSSAPI"
        case plain      = "PLAIN"
        case sha1       = "SCRAM-SHA-1"
        case sha256     = "SCRAM-SHA-256"
    }
}
extension Mongo.SASL
{
    /// Hashes the password, if this mechanism uses hashed passwords.
    func password(hashing password:String, username:String) -> String
    {
        switch self
        {
        case .sha256:
            return password
        
        // note: .sha1 requires additional md5 hashing, using the username
        default:
            fatalError("unimplemented")
        }
    }
}
extension Mongo.SASL:CustomStringConvertible
{
    public
    var description:String
    {
        self.rawValue
    }
}
