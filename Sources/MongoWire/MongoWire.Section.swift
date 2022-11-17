extension MongoWire
{
    @frozen public
    enum Section:UInt8, Sendable
    {
        case body       = 0x00
        case sequence   = 0x01
    }
}
