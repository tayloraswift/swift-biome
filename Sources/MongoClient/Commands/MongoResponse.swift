import BSON
import NIOCore

public
protocol MongoResponse
{
    init(from dictionary:BSON.Dictionary<ByteBufferView>) throws
}
