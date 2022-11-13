extension SCRAM
{
    /// A special type of SCRAM message sent by the client
    /// to initiate authentication.
    @frozen public
    struct Start:Sendable
    {
        let user:String
        public
        let nonce:Nonce
    }
}
extension SCRAM.Start
{
    /// Creates an initial client message with the given username.
    /// This initializer will escape special characters if needed.
    public
    init(username:String)
    {
        self.init(user: SCRAM.escape(name: username), nonce: .random(length: 24))
    }
}
extension SCRAM.Start
{
    /// Returns the string contents of this message without the
    /// GS2 header.
    public
    var bare:String
    {
        "n=\(self.user),r=\(self.nonce)"
    }
}
extension SCRAM.Start
{
    /// Returns this start message as an ordinary SCRAM message.
    public
    var message:SCRAM.Message
    {
        .init("n,,\(self.bare)")
    }
}
