import _MongoKittenCrypto

extension Mongo.SASL
{
    @frozen public
    enum Mechanism:String, Hashable, Sendable 
    {
        case sha1       = "SCRAM-SHA-1"
        case sha256     = "SCRAM-SHA-256"
        case gssapi     = "GSSAPI"
        case plain      = "PLAIN"
    }
}
extension Mongo.SASL.Mechanism
{
    /// Hashes the password, if this mechanism uses hashed passwords.
    func password(hashing password:String, username:String) -> String
    {
        switch self
        {
        case .sha1:
            var md5:MD5 = .init()
            let credentials = "\(username):mongo:\(password)"
            return md5.hash(bytes: [UInt8].init(credentials.utf8)).hexString
        case .sha256:
            return password
        
        default:
            fatalError("unimplemented")
        }
    }
}
