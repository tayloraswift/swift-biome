import NIO
import Logging

public struct ConnectionPoolRequirement: Hashable, Sendable {
    internal enum _Requirement: Hashable, Sendable {
        case writable, new, notPooled
    }
    
    let raw: _Requirement
    
    public static let writable = ConnectionPoolRequirement(raw: .writable)
    public static let new = ConnectionPoolRequirement(raw: .new)
    public static let notPooled = ConnectionPoolRequirement(raw: .notPooled)
}

public struct ConnectionPoolRequest: Sendable, ExpressibleByArrayLiteral {
    public let requirements: Set<ConnectionPoolRequirement>
    
    public init(arrayLiteral requirements: ConnectionPoolRequirement...) {
        self.requirements = Set(requirements)
    }
    
    public static let writable: ConnectionPoolRequest = [.writable]
    public static let basic: ConnectionPoolRequest = []
}

public 
protocol MongoConnectionPool:Sendable
{
    func next(for request:ConnectionPoolRequest) async throws -> Mongo.Connection
    var wireVersion:WireVersion? { get async }
    //var sessionManager: MongoSessionManager { get }
    //var logger: Logger { get }
}

// extension MongoConnection: MongoConnectionPool {
//     public func next(for request: ConnectionPoolRequest) async throws -> MongoConnection {
//         self
//     }
    
//     public var wireVersion: WireVersion? {
//         get async { await serverHandshake?.maxWireVersion }
//     }
// }

