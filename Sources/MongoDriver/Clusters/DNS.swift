import NIOCore
import NIOPosix

/// A placeholder for DNS-related functionality.
enum DNS
{
    enum Connection
    {
    }
}
extension DNS.Connection:Resolver
{
    func initiateAQuery(host:String, port:Int) -> EventLoopFuture<[SocketAddress]>
    {
        fatalError("unimplemented")
    }
    func initiateAAAAQuery(host:String, port:Int) -> EventLoopFuture<[SocketAddress]>
    {
        fatalError("unimplemented")
    }
    func cancelQueries()
    {
        fatalError("unimplemented")
    }
}
extension DNS.Connection
{
    func srv(_ host:Mongo.Host) async throws -> [Mongo.Host] 
    {
        fatalError("unimplemented")
    }
}
