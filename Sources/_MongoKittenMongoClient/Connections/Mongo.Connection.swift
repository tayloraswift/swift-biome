import BSON
import Foundation
import _MongoKittenCrypto
import DNSClient
import NIO
import NIOSSL

extension Mongo
{
    /// @import(NIOCore)
    /// A connection to a mongo host that we have completed an initial handshake with.
    ///
    /// > Warning: This type is not managed! If you are storing instances of this type, 
    /// there must be code elsewhere responsible for closing the wrapped NIO ``Channel``!
    @frozen public
    struct Connection:Sendable
    {
        private
        let channel:any Channel
        let handshake:ServerHandshake

        private
        init(_ channel:any Channel, handshake:ServerHandshake)
        {
            self.channel = channel
            self.handshake = handshake
        }
        func close()
        {
            self.channel.close(mode: .all, promise: nil)
        }
    }
}
extension Mongo.Connection
{
    var closeFuture:EventLoopFuture<Void> 
    {
        self.channel.closeFuture
    }

    static 
    func connect(to host:Mongo.Host, 
        settings:Mongo.ConnectionSettings, 
        group:any EventLoopGroup,
        dns:DNSClient? = nil) async throws -> Self 
    {
        let unestablished:Mongo.UnestablishedConnection = 
            try await .connect(to: host, settings: settings, group: group, dns: dns)

        do
        {
            let handshake:ServerHandshake = try await unestablished.establish(
                authentication: settings.authentication)
            
            let connection:Self = .init(unestablished.channel, handshake: handshake)
            if  let authentication:Mongo.ConnectionSettings.Authentication = 
                    settings.authentication,
                let mechanism:Mongo.ConnectionSettings.Authentication.Mechanism =
                    authentication.mechanism(handshake: handshake)
            {
                try await connection.authenticate(with: authentication, mechanism: mechanism)
            }
            return connection
        }
        catch let error
        {
            try await unestablished.channel.close()
            throw error
        }
    }

    func reestablish(
        authentication:Mongo.ConnectionSettings.Authentication?) async throws -> Self
    {
        let unestablished:Mongo.UnestablishedConnection = .init(channel: self.channel)
        let handshake:ServerHandshake = try await unestablished.establish(
                authentication: authentication)
        return .init(unestablished.channel, handshake: handshake)
    }
}

extension Mongo.Connection
{
    func run<T>(codable command:__owned some Encodable,
        against database:Mongo.Database,
        transaction:Never? = nil,
        session:Mongo.Session.ID?,
        returning _:T.Type = T.self) async throws -> T
        where T:Decodable
    {
        let reply:OpMessage = try await self.run(encodable: command, against: database, 
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
    
    func run(encodable command:__owned some Encodable, against database:Mongo.Database,
        transaction:Never? = nil,
        session:Mongo.Session.ID?) async throws -> OpMessage 
    {
        try await self.run(command: try BSONEncoder().encode(command), against: database, 
            transaction: transaction, 
            session: session)
    }

    func run(command:__owned Document, against database:Mongo.Database,
        transaction:Never? = nil,
        session:Mongo.Session.ID?) async throws -> OpMessage 
    {
        var command:Document = command
            command.appendValue(database.name, forKey: "$db")
        
        if let session
        {
            command.appendValue(session.bson, forKey: "lsid")
        }
        
        // if let transaction:Mongo.Transaction 
        // {
        //     command.appendValue(transaction.number, forKey: "txnNumber")
        //     command.appendValue(transaction.autocommit, forKey: "autocommit")

        //     if await transaction.startTransaction() 
        //     {
        //         command.appendValue(true, forKey: "startTransaction")
        //     }
        // }
        
        return try await withCheckedThrowingContinuation
        {
            (continuation:CheckedContinuation<OpMessage, Error>) in
            self.channel.writeAndFlush((command, continuation), promise: nil)
        }
    }
}

extension Mongo.Connection
{
    private
    func authenticate(with authentication:Mongo.ConnectionSettings.Authentication,
        mechanism:Mongo.ConnectionSettings.Authentication.Mechanism) async throws 
    {
        switch mechanism 
        {
        case .sha1:
            return try await self.authenticateSASL(hasher: SHA1.init(),
                database: authentication.database, 
                username: authentication.username,
                password: authentication.password)
        case .sha256:
            return try await self.authenticateSASL(hasher: SHA256(),
                database: authentication.database, 
                username: authentication.username,
                password: authentication.password)
        default:
            fatalError("authentication mechanism \(mechanism) has not been implemented yet")
        }
    }
}

// Johannis + Jaap wrote most of the code below, which we inherited from MongoKitten. 
// i have not gotten around to integrating it into the rest of the driver.
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
    func authenticateSASL<H:SASLHash>(hasher:H, 
        database:Mongo.Database, 
        username:String, 
        password:String) async throws 
    {
        let context = SCRAM<H>(hasher)

        let rawRequest = try context.authenticationString(forUser: username)
        let request = Data(rawRequest.utf8).base64EncodedString()
        let command = SASLStart(mechanism: H.algorithm, payload: request)

        // NO session must be used here: https://github.com/mongodb/specifications/blob/master/source/sessions/driver-sessions.rst#when-opening-and-authenticating-a-connection
        // Forced on the current connection
        var reply:SASLReply = try await self.run(codable: command,
            against: database,
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
            against: database,
            session: nil)
        
        let successReply = try reply.payload.base64Decoded()
        try context.completeAuthentication(withResponse: successReply)
        
        if  reply.done 
        {
            return
        }
        
        let final:SASLContinue = .init(conversation: reply.conversationId, payload: "")

        reply = try await self.run(codable: final,
            against: database,
            session: nil)
        
        guard reply.done else {
            throw MongoAuthenticationError(reason: .malformedAuthenticationDetails)
        }
    }
}
