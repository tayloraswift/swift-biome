import BSONDecoding
import BSONEncoding
import MongoDriver
import NIOCore

struct Ordinal:Hashable, Sendable
{
    let id:Int
    let value:Int64
}
extension Ordinal:MongoScheme
{
    init(bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self.init(id: try bson["_id"].decode(to: Int.self),
            value: try bson["ordinal"].decode(to: Int64.self))
    }

    var bson:BSON.Document<[UInt8]>
    {
        [
            "_id": .int64(Int64.init(self.id)),
            "ordinal": .int64(self.value),
        ]
    }
}
extension Ordinal:CustomStringConvertible
{
    var description:String
    {
        """
        {_id: \(self.id), ordinal: \(self.value)}
        """
    }
}
