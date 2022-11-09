import NIOSSL

extension Mongo
{
    @frozen public
    struct ConnectionSettings:Sendable
    {
        public
        let authentication:Authentication?
        public
        let queryTimeout:Duration
        public
        let tls:TLS?

        @inlinable public
        init(authentication:Authentication? = nil,
            queryTimeout:Duration = .seconds(15),
            tls:TLS? = nil)
        {
            self.authentication = authentication
            self.queryTimeout = queryTimeout
            self.tls = tls
        }
    }
}
extension Mongo.ConnectionSettings
{
    public
    init(_ string:Mongo.ConnectionString)
    {
        let tls:TLS? = string.tlsCAFile.map(TLS.init(certificatePath:))
        let authentication:Authentication?
        if let user:(name:String, password:String) = string.user
        {
            authentication = .init(
                mechanism: string.authMechanism, 
                username: user.name, 
                password: user.password,
                database: string.authSource ?? string.defaultauthdb ?? .admin)
        }
        else
        {
            authentication = nil
        }
        self.init(authentication: authentication, tls: tls)
    }
}
extension Mongo.ConnectionSettings
{
    public
    struct TLS:Sendable
    {
        // TODO: cache certificate loading
        let certificatePath:String
        //let CaCertificate:NIOSSLCertificate?
    }

    @frozen public
    struct Authentication:Equatable, Sendable
    {
        @frozen public
        enum Mechanism:String, Equatable, Sendable 
        {
            case sha1       = "SCRAM-SHA-1"
            case sha256     = "SCRAM-SHA-256"
            case x509       = "MONGODB-X509"
            case aws        = "MONGODB-AWS"
            case gssapi     = "GSSAPI"
            case plain      = "PLAIN"

            var sasl:Mongo.SASL.Mechanism?
            {
                switch self
                {
                case .sha1:     return .sha1
                case .sha256:   return .sha256
                case .gssapi:   return .gssapi
                case .plain:    return .plain
                case .x509, .aws:
                    return nil
                }
            }
        }

        public
        let mechanism:Mechanism?
        public
        let username:String
        public
        let password:String
        public
        let database:Mongo.Database

        var user:Mongo.User?
        {
            if case nil = self.mechanism
            {
                return .init(self.database, self.username)
            } 
            else 
            {
                return nil
            }
        }
    }
}
