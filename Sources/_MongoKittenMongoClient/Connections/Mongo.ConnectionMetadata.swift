import NIOSSL

extension Mongo
{
    struct ConnectionMetadata:Sendable
    {
        struct TLS:Sendable
        {
            // TODO: cache certificate loading
            let certificatePath:String
            //let CaCertificate:NIOSSLCertificate?
        }

        let authentication:Authentication
        let authenticationSource:String?
        let tls:TLS?
    }
}
