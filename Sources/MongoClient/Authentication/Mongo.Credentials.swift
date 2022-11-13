extension Mongo
{
    @frozen public
    struct Credentials:Equatable, Sendable
    {
        public
        let authentication:Mongo.Authentication?
        public
        let username:String
        public
        let password:String
        public
        let database:Mongo.Database

        @inlinable public
        init(authentication:Mongo.Authentication?,
            username:String,
            password:String,
            database:Mongo.Database = .admin)
        {
            self.authentication = authentication
            self.username = username
            self.password = password
            self.database = database
        }
    }
}
extension Mongo.Credentials
{
    var user:Mongo.User
    {
        .init(self.database, self.username)
    }
}
extension Mongo.Credentials
{
    func sasl(defaults:Set<Mongo.SASL>?) -> Mongo.SASL?
    {
        //  https://github.com/mongodb/specifications/blob/master/source/auth/auth.rst
        //  '''
        //  When a user has specified a mechanism, regardless of the server version,
        //  the driver MUST honor this.
        //  '''
        switch self.authentication
        {
        case .sasl(let sasl)?:
            return sasl
        case .x509?:
            return nil
        case nil:
            break
        }
        //  '''
        //  If SCRAM-SHA-256 is present in the list of mechanism, then it MUST be used
        //  as the default; otherwise, SCRAM-SHA-1 MUST be used as the default,
        //  regardless of whether SCRAM-SHA-1 is in the list. Drivers MUST NOT attempt
        //  to use any other mechanism (e.g. PLAIN) as the default.
        //
        //  If `saslSupportedMechs` is not present in the handshake response for
        //  mechanism negotiation, then SCRAM-SHA-1 MUST be used when talking to
        //  servers >= 3.0. Prior to server 3.0, MONGODB-CR MUST be used.
        //  '''
        if case true? = defaults?.contains(.sha256)
        {
            return .sha256
        }
        else
        {
            return .sha1
        }
    }
}
