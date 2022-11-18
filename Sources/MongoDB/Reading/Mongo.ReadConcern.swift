import BSONDecoding
import BSONEncoding
import NIOCore

extension Mongo
{
    @frozen public
    enum ReadConcern:String, Hashable, Sendable
    {
        case local
        case available
        case majority
        case linearizable
        case snapshot
    }
}
extension Mongo.ReadConcern:MongoScheme
{
    public
    init(bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self = try bson["level"].decode(cases: Self.self)
    }
    public
    var bson:BSON.Document<[UInt8]>
    {
        [
            "level": .string(self.rawValue),
        ]
    }
}
