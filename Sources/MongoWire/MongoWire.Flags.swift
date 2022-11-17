extension MongoWire
{
    @frozen public
    struct Flags:OptionSet, Sendable 
    {
        public
        var rawValue:UInt32
    
        @inlinable public
        init(rawValue:UInt32)
        {
            self.rawValue = rawValue
        }
    }
}
extension MongoWire.Flags
{
    /// The message ends with 4 bytes containing a CRC-32C [1] checksum.
    /// See [Checksum](https://www.mongodb.com/docs/manual/reference/mongodb-wire-protocol/#std-label-wire-msg-checksum)
    /// for details.
    public static
    let checksumPresent:Self = .init(rawValue: 1 << 0)
    
    /// Another message will follow this one without further action from the receiver.
    /// The receiver MUST NOT send another message until receiving one with `moreToCome`
    /// set to 0 as sends may block, causing deadlock. Requests with the `moreToCome`
    /// bit set will not receive a reply. Replies will only have this set in response
    /// to requests with the `exhaustAllowed` bit set.
    public static
    let moreToCome:Self = .init(rawValue: 1 << 1)
    
    /// The client is prepared for multiple replies to this request using the
    /// `moreToCome` bit. The server will never produce replies with the `moreToCome`
    /// bit set unless the request has this bit set.
    ///
    /// This ensures that multiple replies are only sent when the network layer of
    /// the requester is prepared for them.
    public static
    let exhaustAllowed:Self = .init(rawValue: 1 << 16)

    @inlinable public
    init(validating flags:UInt32) throws
    {
        if let error:MongoWire.FlagsError = .init(flags: flags)
        {
            throw error
        }
        else
        {
            self.init(rawValue: flags)
        }
    }
}
