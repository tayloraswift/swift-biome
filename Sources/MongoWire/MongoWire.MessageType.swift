extension MongoWire
{
    @frozen public
    enum MessageType:Int32, Sendable
    {
        // case compressed = 2012
        case message    = 2013
    }
}
