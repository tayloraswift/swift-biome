extension Mongo
{
    @frozen public
    enum MessageSection:UInt8, Sendable
    {
        case body       = 0x00
        case sequence   = 0x01
    }
}
