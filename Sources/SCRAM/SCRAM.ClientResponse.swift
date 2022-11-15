import Base64
import MessageAuthentication

extension SCRAM
{
    /// A client’s response to a SCRAM challenge, authenticating the client.
    @frozen public
    struct ClientResponse<Hash> where Hash:MessageAuthenticationHash
    {
        public
        let message:Message
        @usableFromInline
        let signature:Hash

        @usableFromInline
        init(message:Message, signature:Hash)
        {
            self.message = message
            self.signature = signature
        }
    }
}
extension SCRAM.ClientResponse
{
    @inlinable public
    init(challenge:SCRAM.Challenge, password:String,
        received:SCRAM.Message,
        sent:SCRAM.Start) throws
    {
        // server appends its own nonce to the one we generated
        guard challenge.nonce.string.starts(with: sent.nonce.string)
        else
        {
            throw SCRAM.ChallengeError.nonce(challenge.nonce, sent: sent.nonce)
        }

        let prefix:String = "c=biws,r=\(challenge.nonce)"
        let message:String = "\(sent.bare),\(received),\(prefix)"

        // TODO: Cache saltedKey, as it takes a long time to compute
        let saltedKey:MessageAuthenticationKey<Hash> = .init(Hash.pbkdf2(password: password.utf8,
            salt: Base64.decode(challenge.salt, to: [UInt8].self),
            iterations: challenge.iterations))

        let serverKey:Hash = saltedKey.authenticate("Server Key".utf8)
        let clientKey:Hash = saltedKey.authenticate("Client Key".utf8)
        let storedKey:Hash = .init(hashing: clientKey)
        let signature:Hash = .init(authenticating: message.utf8, key: storedKey)

        let proof:[UInt8] = zip(clientKey, signature).map(^)

        self.init(message: .init("\(prefix),p=\(Base64.encode(proof))"),
            signature: .init(authenticating: message.utf8, key: serverKey))
    }
}
extension SCRAM.ClientResponse
{
    /// Returns [`true`]() if the given server response is consistent with
    /// the server signature computed for this client response.
    @inlinable public
    func verify(_ response:SCRAM.ServerResponse) -> Bool
    {
        self.signature.elementsEqual(response.signature)
    }
}
