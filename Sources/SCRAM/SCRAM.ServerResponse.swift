import Base64

extension SCRAM
{
    /// A server’s response to a client’s response to its SCRAM challenge,
    /// authenticating the server.
    @frozen public
    struct ServerResponse
    {
        @usableFromInline
        let signature:[UInt8]

        init(signature:[UInt8])
        {
            self.signature = signature
        }
    }
}
extension SCRAM.ServerResponse
{
    public
    init(from message:SCRAM.Message) throws
    {
        for (attribute, value):(SCRAM.Attribute, Substring) in message.fields()
        {
            if case .verification = attribute
            {
                self.init(signature: Base64.decode(value.utf8, to: [UInt8].self))
                return
            }
            else
            {
                continue
            }
        }
        throw SCRAM.ServerResponseError.init(missing: .verification)
    }
}
