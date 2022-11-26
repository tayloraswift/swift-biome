import BSONSchema

extension Mongo.Authentication
{
    /// A namespace for SASL (Simple Authentication and Security Layer) types.
    @frozen public
    enum SASL:String, Hashable, Sendable 
    {
        case aws        = "MONGODB-AWS"
        case gssapi     = "GSSAPI"
        case plain      = "PLAIN"
        case sha1       = "SCRAM-SHA-1"
        case sha256     = "SCRAM-SHA-256"
    }
}
extension Mongo.Authentication.SASL:CustomStringConvertible
{
    @inlinable public
    var description:String
    {
        self.rawValue
    }
}
extension Mongo.Authentication.SASL:BSONScheme
{
}
