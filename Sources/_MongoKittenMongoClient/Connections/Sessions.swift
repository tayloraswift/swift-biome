import Foundation
import Atomics
import NIOConcurrencyHelpers
import BSON
import NIO

public 
struct SessionIdentifier:Hashable, Sendable 
{
    let x:UInt64
    let y:UInt64

    static
    var _random:Self
    {
        .init()
    }

    init() 
    {
        self.x = .random(in: .min ... .max)
        self.y = 0
    }

    private
    var binary:Binary
    {
        var buffer:ByteBuffer = .init()
        buffer.reserveCapacity(16)
        buffer.writeInteger(self.x)
        buffer.writeInteger(self.y)
        return .init(subType: .uuid, buffer: buffer)
    }

    var bson:Document
    {
        [
            "id": self.binary
        ]
    }
}

// public final class MongoClientSession: @unchecked Sendable {
//     private let serverSession: MongoServerSession
//     private weak var sessionManager: MongoSessionManager?
//     internal let clusterTime: Document?
//     internal let options: MongoSessionOptions
//     public var sessionId: SessionIdentifier {
//         return serverSession.sessionId
//     }

//     // Can be `nil` when the session is implicit
//     init(
//         serverSession: MongoServerSession,
//         sessionManager: MongoSessionManager?,
//         options: MongoSessionOptions
//     ) {
//         self.serverSession = serverSession
//         self.sessionManager = sessionManager
//         self.options = options
//         self.clusterTime = nil
//     }
    
//     public func startTransaction(autocommit: Bool) -> MongoTransaction {
//         return MongoTransaction(
//             number: serverSession.nextTransactionNumber(),
//             autocommit: autocommit
//         )
//     }

//     func advanceClusterTime(to time: Document) {
//         // Increase if the new time is in the future
//         // Ignore if the new time <= the current time
//     }

//     //    public func end() -> EventLoopFuture<Void> {
//     //        let command = EndSessionsCommand(
//     //            [sessionId],
//     //            inNamespace: connection["admin"]["$cmd"].namespace
//     //        )
//     //
//     //        return command.execute(on: connection)
//     //    }

//     deinit {
//         sessionManager?.releaseSession(serverSession)
//     }
// }

// internal final class MongoServerSession: @unchecked Sendable {
//     internal let sessionId: SessionIdentifier
//     internal let lastUse: Date
//     private let transaction = ManagedAtomic<Int>(1)

//     func nextTransactionNumber() -> Int {
//         transaction.loadThenWrappingIncrement(ordering: .relaxed)
//     }

//     init(for sessionId: SessionIdentifier) {
//         self.sessionId = sessionId
//         self.lastUse = Date()
//     }

//     fileprivate static let allocator = ByteBufferAllocator()
//     static var random: MongoServerSession {
//         return MongoServerSession(for: SessionIdentifier())
//     }
// }

// /// A LIFO (Last In, First Out) pool of sessions with a MongoDB "cluster" of 1 or more hosts
// public final class MongoSessionManager: @unchecked Sendable {
//     private let lock = NSLock()
//     private var availableSessions = [MongoServerSession]()
//     private let implicitSession: MongoServerSession
//     public nonisolated let implicitClientSession: MongoClientSession

//     public init() {
//         self.implicitSession = MongoServerSession.random
//         self.implicitClientSession = MongoClientSession(
//             serverSession: implicitSession,
//             sessionManager: nil,
//             options: MongoSessionOptions()
//         )
//     }

//     internal func releaseSession(_ session: MongoServerSession) {
//         lock.lock()
//         defer { lock.unlock() }
//         self.availableSessions.append(session)
//     }

//     /// Retains an existing or generates a new session to MongoDB.
//     /// The session is returned to the pool when the ClientSession's `deinit` triggers
//     public func retainSession(with options: MongoSessionOptions) -> MongoClientSession {
//         lock.lock()
//         defer { lock.unlock() }
//         let serverSession: MongoServerSession

//         if availableSessions.count > 0 {
//             serverSession = availableSessions.removeLast()
//         } else {
//             serverSession = .random
//         }

//         return MongoClientSession(serverSession: serverSession, sessionManager: self, options: options)
//     }
// }

// /// TODO: Verify server feature version with https://github.com/mongodb/specifications/blob/master/source/retryable-writes/retryable-writes.rst#supported-server-versions
// /// Supported single-statement write operations include insertOne(), updateOne(), replaceOne(), deleteOne(), findOneAndDelete(), findOneAndReplace(), and findOneAndUpdate().
// ///
// /// Supported multi-statement write operations include insertMany() and bulkWrite(). The ordered option may be true or false. In the case of bulkWrite(), UpdateMany or DeleteMany operations within the requests parameter may make some write commands ineligible for retryability. Drivers MUST evaluate eligibility for each write command sent as part of the bulkWrite()
// /// https://github.com/mongodb/specifications/blob/master/source/retryable-writes/retryable-writes.rst#how-will-users-know-which-operations-are-supported
// /// Write commands specifying an unacknowledged write concern (e.g. {w: 0})) do not support retryable behavior.
// /// https://github.com/mongodb/specifications/blob/master/source/retryable-writes/retryable-writes.rst#unsupported-write-operations
// /// TODO: Write commands
// /// In MongoDB 4.0 the only supported retryable write commands within a transaction are commitTransaction and abortTransaction. Therefore drivers MUST NOT retry write commands within transactions even when retryWrites has been enabled on the MongoClient. Drivers MUST retry the commitTransaction and abortTransaction commands even when retryWrites has been disabled on the MongoClient. commitTransaction and abortTransaction are retryable write commands and MUST be retried according to the Retryable Writes Specification.
// public struct MongoSessionOptions: Sendable {
//     public var casualConsistency: Bool?
//     public var defaultTransactionOptions: MongoTransactionOptions?

//     public init() {}
// }
