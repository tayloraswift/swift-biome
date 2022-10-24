import BSON
import Foundation
import _MongoKittenCrypto
import NIO
import DNSClient
import Atomics
import Logging
import Metrics

#if canImport(NIOTransportServices) && os(iOS)
import Network
import NIOTransportServices
#else
import NIOSSL
#endif

public struct MongoHandshakeResult {
    public let sent: Date
    public let received: Date
    public let handshake: ServerHandshake
    public var interval: Double {
        received.timeIntervalSince(sent)
    }
    
    init(sentAt sent: Date, handshake: ServerHandshake) {
        self.sent = sent
        self.received = Date()
        self.handshake = handshake
    }
}

extension Mongo
{
    // not managed! someone else must be responsible for closing the NIO channel!
    @frozen public
    struct Connection:Sendable
    {
        //private
        let channel:any Channel
        let handshake:ServerHandshake

        private
        init(_ channel:any Channel, handshake:ServerHandshake)
        {
            self.channel = channel
            self.handshake = handshake
        }
        // deinit 
        // {
        //     channel.close(mode: .all, promise: nil)
        // }
    }
}
extension Mongo.Connection
{
    static 
    func connect(to host:Mongo.Host, metadata:Mongo.ConnectionMetadata, 
        on group:any EventLoopGroup,
        resolver:DNSClient? = nil) async throws -> Self 
    {
        let unconfirmed:Mongo.UnconfirmedConnection = 
            try await .connect(to: host, tls: metadata.tls, on: group, resolver: resolver)

        do
        {
            let authenticationDatabase:String = metadata.authenticationSource ?? "admin"

            let handshake:ServerHandshake = try await unconfirmed.confirm(
                authenticationDatabase: authenticationDatabase,
                credentials: metadata.authentication)
            
            let connection:Self = .init(unconfirmed.channel, handshake: handshake)
            try await connection.authenticate(authenticationDatabase: authenticationDatabase,
                credentials: metadata.authentication,
                handshake: handshake)
            return connection
        }
        catch let error
        {
            try await unconfirmed.channel.close()
            throw error
        }
    }
}

extension Mongo.Connection 
{
    // public nonisolated var logger: Logger { context.logger }
    // var queryTimer: Metrics.Timer?
    // public internal(set) var lastHeartbeat: MongoHandshakeResult?
    // public var queryTimeout: TimeAmount? = .seconds(30)
    
    // public var isMetricsEnabled = false {
    //     didSet {
    //         if isMetricsEnabled, !oldValue {
    //             queryTimer = Metrics.Timer(label: "org.openkitten.mongokitten.core.queries")
    //         } else {
    //             queryTimer = nil
    //         }
    //     }
    // }
    
    // /// A LIFO (Last In, First Out) holder for sessions
    // public let sessionManager: MongoSessionManager
    // public 
    // var implicitSession:MongoClientSession 
    // {
    //     return sessionManager.implicitClientSession
    // }
    // public nonisolated var implicitSessionId: SessionIdentifier {
    //     return implicitSession.sessionId
    // }
    
    // /// The current request ID, used to generate unique identifiers for MongoDB commands
    // internal let context: MongoClientContext
    // public var serverHandshake: ServerHandshake? {
    //     get async { await context.serverHandshake }
    // }
    
    // public nonisolated var closeFuture: EventLoopFuture<Void> {
    //     return channel.closeFuture
    // }
    
    // public nonisolated var eventLoop: EventLoop { return channel.eventLoop }
    // public var allocator: ByteBufferAllocator { return channel.allocator }
    
    // public let slaveOk = ManagedAtomic(false)
    
    
    // /// Creates a connection that can communicate with MongoDB over a channel
    // public init(channel: Channel, context: MongoClientContext, sessionManager: MongoSessionManager = .init()) {
    //     self.sessionManager = sessionManager
    //     self.channel = channel
    //     self.context = context
    // }
    
    
    // func executeMessage<Request>(_ message:Request) async throws -> MongoServerReply 
    //     where Request:MongoRequestMessage
    // {
        
    //     if await self.context.didError {
    //         channel.close(mode: .all, promise: nil)
    //         throw MongoError(.queryFailure, reason: .connectionClosed)
    //     }
        
    //     let promise = self.eventLoop.makePromise(of: MongoServerReply.self)
    //     await self.context.setReplyCallback(forRequestId: message.header.requestId, completing: promise)
        
    //     var buffer = self.channel.allocator.buffer(capacity: Int(message.header.messageLength))
    //     message.write(to: &buffer)
    //     try await self.channel.writeAndFlush(buffer)
        
    //     if let queryTimeout = queryTimeout {
    //         Task {
    //             try await Task.sleep(nanoseconds: UInt64(queryTimeout.nanoseconds))
    //             promise.fail(MongoError(.queryTimeout, reason: nil))
    //         }
    //     }
        
    //     return try await promise.futureResult.get()
    // }


    
    public 
    func close() async throws
    {
        try await self.channel.close()
    }
}

// public 
// struct MongoServerError:Error 
// {
//     public 
//     let document:Document
// }

extension Mongo.Connection
{
    public 
    func run<T>(codable command:__owned some Encodable,
        against namespace:MongoNamespace,
        transaction:MongoTransaction? = nil,
        session:SessionIdentifier?,
        returning _:T.Type = T.self) async throws -> T
        where T:Decodable
    {
        let reply:OpMessage = try await self.run(encodable: command, against: namespace, 
            transaction: transaction, 
            session: session)
        guard let document:Document = reply.first
        else
        {
            throw MongoCommandError.emptyReply
        }

        try document.status()
        return try BSONDecoder().decode(T.self, from: document)
    }
    
    public 
    func run(encodable command:__owned some Encodable, against namespace:MongoNamespace,
        transaction:MongoTransaction? = nil,
        session:SessionIdentifier?) async throws -> OpMessage 
    {
        try await self.run(command: try BSONEncoder().encode(command), against: namespace, 
            transaction: transaction, 
            session: session)
    }

    public 
    func run(command:__owned Document, against namespace:MongoNamespace,
        transaction:MongoTransaction?,
        session:SessionIdentifier?) async throws -> OpMessage 
    {
        //let startDate = Date()
        var command:Document = command
            command.appendValue(namespace.databaseName, forKey: "$db")
        
        if let session
        {
            command.appendValue(session.bson, forKey: "lsid")
        }
        
        // TODO: When retrying a write, don't resend transaction messages except commit & abort
        if let transaction:MongoTransaction 
        {
            command.appendValue(transaction.number, forKey: "txnNumber")
            command.appendValue(transaction.autocommit, forKey: "autocommit")

            if await transaction.startTransaction() 
            {
                command.appendValue(true, forKey: "startTransaction")
            }
        }
        
        return try await withCheckedThrowingContinuation
        {
            (continuation:CheckedContinuation<OpMessage, Error>) in
            self.channel.writeAndFlush((command, continuation), promise: nil)
        }

        // if let queryTimer = queryTimer {
        //     queryTimer.record(-startDate.timeIntervalSinceNow)
        // }
    }
}

extension Mongo.Connection
{
    private
    func authenticate(authenticationDatabase source:String,
        credentials:Mongo.Authentication,
        handshake:ServerHandshake) async throws 
    {
        let namespace = MongoNamespace(to: "$cmd", inDatabase: source)

        var credentials = credentials

        if case .auto(let user, let pass) = credentials {
            credentials = try selectAuthenticationAlgorithm(forUser: user, password: pass, handshake: handshake)
        }

        switch credentials {
        case .unauthenticated:
            return
        case .auto(let username, let password):
            if let mechanisms = handshake.saslSupportedMechs {
                nextMechanism: for mechanism in mechanisms {
                    switch mechanism {
                    case "SCRAM-SHA-1":
                        return try await self.authenticateSASL(hasher: SHA1(), namespace: namespace, username: username, password: password)
                    case "SCRAM-SHA-256":
                        // TODO: Enforce minimum 4096 iterations
                        return try await self.authenticateSASL(hasher: SHA256(), namespace: namespace, username: username, password: password)
                    default:
                        continue nextMechanism
                    }
                }

                throw MongoAuthenticationError(reason: .unsupportedAuthenticationMechanism)
            } else if handshake.maxWireVersion.supportsScramSha1 {
                return try await self.authenticateSASL(hasher: SHA1(), namespace: namespace, username: username, password: password)
            } else {
                return try await self.authenticateCR(username, password: password, namespace: namespace)
            }
        case .scramSha1(let username, let password):
            return try await self.authenticateSASL(hasher: SHA1(), namespace: namespace, username: username, password: password)
        case .scramSha256(let username, let password):
            return try await self.authenticateSASL(hasher: SHA256(), namespace: namespace, username: username, password: password)
        case .mongoDBCR(let username, let password):
            return try await self.authenticateCR(username, password: password, namespace: namespace)
        }
    }

    private 
    func selectAuthenticationAlgorithm(forUser user:String, password:String, 
        handshake:ServerHandshake) throws -> Mongo.Authentication 
    {
        if let saslSupportedMechs = handshake.saslSupportedMechs {
            nextMechanism: for mech in saslSupportedMechs {
                switch mech {
                case "SCRAM-SHA-256":
                    return .scramSha256(username: user, password: password)
                case "SCRAM-SHA-1":
                    return .scramSha1(username: user, password: password)
                default:
                    // Unknown algorithm
                    continue nextMechanism
                }
            }
        }

        if handshake.maxWireVersion.supportsScramSha1 {
            return .scramSha1(username: user, password: password)
        } else {
            return .mongoDBCR(username: user, password: password)
        }
    }
}

fileprivate struct GetNonce: Encodable {
    let getnonce: Int32 = 1
}

fileprivate struct GetNonceResult: Decodable {
    let nonce: String
}

fileprivate struct AuthenticateCR: Encodable {
    let authenticate: Int32 = 1
    let nonce: String
    let user: String
    let key: String

    public init(nonce: String, user: String, key: String) {
        self.nonce = nonce
        self.user = user
        self.key = key
    }
}

extension Mongo.Connection 
{
    func authenticateCR(_ username:String, password:String, namespace:MongoNamespace) async throws  
    {
        let nonceReply:GetNonceResult = try await self.run(codable: GetNonce.init(),
            against: namespace,
            session: nil)
        
        let nonce:String = nonceReply.nonce

        var md5:MD5 = .init()

        let credentials:String = "\(username):mongo:\(password)"
        let digest:String = md5.hash(bytes: [UInt8].init(credentials.utf8)).hexString
        let key:String = nonce + username + digest

        let authenticate:AuthenticateCR = .init(nonce: nonce, user: username, 
            key: md5.hash(bytes: [UInt8].init(key.utf8)).hexString)

        let authenticationReply:OpMessage = try await self.run(encodable: authenticate,
            against: namespace,
            session: nil)
        
        if  let document:Document = authenticationReply.first
        {
            try document.status()
        }
        else
        {
            throw MongoCommandError.emptyReply
        }
    }
}


enum SASLMechanism: String, Codable {
    case scramSha1 = "SCRAM-SHA-1"
    case scramSha256 = "SCRAM-SHA-256"

    var md5Digested: Bool {
        return self == .scramSha1
    }
}

enum BinaryOrString: Codable {
    case binary(Binary)
    case string(String)
    
    public init(from decoder: Decoder) throws {
        do {
            self = try .binary(Binary(from: decoder))
        } catch {
            self = try .string(String(from: decoder))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .binary(let binary):
            try binary.encode(to: encoder)
        case .string(let string):
            try string.encode(to: encoder)
        }
    }
    
    var string: String? {
        switch self {
        case .binary(let binary):
            return String(data: binary.data, encoding: .utf8)
        case .string(let string):
            return string
        }
    }
    
    func base64Decoded() throws -> String {
        switch self {
        case .binary(let binary):
            return try (String(data: binary.data, encoding: .utf8) ?? "").base64Decoded()
        case .string(let string):
            return try string.base64Decoded()
        }
    }
}

/// A SASLStart message initiates a SASL conversation, in our case, used for SCRAM-SHA-xxx authentication.
struct SASLStart: Codable {
    private var saslStart: Int32 = 1
    let mechanism: SASLMechanism
    let payload: BinaryOrString

    init(mechanism: SASLMechanism, payload: String) {
        self.mechanism = mechanism
        self.payload = .string(payload)
    }
}

/// A generic type containing a payload and conversationID.
/// The payload contains an answer to the previous SASLMessage.
///
/// For SASLStart it contains a challenge the client needs to answer
/// For SASLContinue it contains a success or failure state
///
/// If no authentication is needed, SASLStart's reply may contain `done: true` meaning the SASL proceedure has ended
struct SASLReply: Decodable {
    let conversationId: Int32
    let done: Bool
    let payload: BinaryOrString

    init(reply: MongoServerReply) throws {
        try reply.assertOK(or: MongoAuthenticationError(reason: .anyAuthenticationFailure))
        let doc = try reply.getDocument()

        if let conversationId = doc["conversationId"] as? Int {
            self.conversationId = Int32(conversationId)
        } else if let conversationId = doc["conversationId"] as? Int32 {
            self.conversationId = conversationId
        } else {
            throw try MongoGenericErrorReply(reply: reply)
        }

        guard let done = doc["done"] as? Bool else {
            throw try MongoGenericErrorReply(reply: reply)
        }

        self.done = done

        if let payload = doc["payload"] as? String {
            self.payload = .string(payload)
        } else  if let payload = doc["payload"] as? Binary {
            self.payload = .binary(payload)
        } else {
            throw try MongoGenericErrorReply(reply: reply)
        }
    }
}

/// A SASLContinue message contains the previous conversationId (from the SASLReply to SASLStart).
/// The payload must contian an answer to the SASLReply's challenge
struct SASLContinue: Codable {
    private var saslContinue: Int32 = 1
    let conversationId: Int32
    let payload: BinaryOrString

    init(conversation: Int32, payload: String) {
        self.conversationId = conversation
        self.payload = .string(payload)
    }
}

protocol SASLHash: Hash {
    static var algorithm: SASLMechanism { get }
}

extension SHA1: SASLHash {
    static let algorithm = SASLMechanism.scramSha1
}

extension SHA256: SASLHash {
    static let algorithm = SASLMechanism.scramSha256
}

extension Mongo.Connection 
{
    /// Handles a SCRAM authentication flow
    ///
    /// The Hasher `H` specifies the hashing algorithm used with SCRAM.
    func authenticateSASL<H: SASLHash>(hasher: H, namespace: MongoNamespace, username: String, password: String) async throws {
        let context = SCRAM<H>(hasher)

        let rawRequest = try context.authenticationString(forUser: username)
        let request = Data(rawRequest.utf8).base64EncodedString()
        let command = SASLStart(mechanism: H.algorithm, payload: request)

        // NO session must be used here: https://github.com/mongodb/specifications/blob/master/source/sessions/driver-sessions.rst#when-opening-and-authenticating-a-connection
        // Forced on the current connection
        var reply:SASLReply = try await self.run(codable: command,
            against: namespace,
            session: nil)
        
        if  reply.done 
        {
            return
        }

        let preppedPassword: String

        if H.algorithm.md5Digested {
            var md5 = MD5()
            let credentials = "\(username):mongo:\(password)"
            preppedPassword = md5.hash(bytes: Array(credentials.utf8)).hexString
        } else {
            preppedPassword = password
        }

        let challenge = try reply.payload.base64Decoded()
        let rawResponse = try context.respond(toChallenge: challenge, password: preppedPassword)
        let response = Data(rawResponse.utf8).base64EncodedString()

        let next:SASLContinue = .init(conversation: reply.conversationId, payload: response)

        reply = try await self.run(codable: next,
            against: namespace,
            session: nil)
        
        let successReply = try reply.payload.base64Decoded()
        try context.completeAuthentication(withResponse: successReply)
        
        if  reply.done 
        {
            return
        }
        
        let final:SASLContinue = .init(conversation: reply.conversationId, payload: "")

        reply = try await self.run(codable: final,
            against: namespace,
            session: nil)
        
        guard reply.done else {
            throw MongoAuthenticationError(reason: .malformedAuthenticationDetails)
        }
    }
}
