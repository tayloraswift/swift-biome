import Base64
import MessageAuthentication

extension SCRAM
{
    @frozen public
    struct Proof<Hash> where Hash:MessageAuthenticationHash
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
extension SCRAM.Proof
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
extension SCRAM.Proof
{
    @inlinable public
    func verify(acceptance message:SCRAM.Message) throws 
    {
        for (attribute, value):(SCRAM.Attribute, Substring) in message.fields()
        {
            guard case .verification = attribute
            else
            {
                continue
            }
            if self.signature.elementsEqual(Base64.decode(value.utf8, to: [UInt8].self))
            {
                return
            }
            else
            {
                fatalError("unimplemented")
            }
        }
    }
}
