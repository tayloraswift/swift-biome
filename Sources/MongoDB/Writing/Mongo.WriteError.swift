import BSONDecoding
import NIOCore

extension Mongo
{
    @frozen public
    struct WriteError:Equatable, Error, Sendable
    {
        public
        let index:Int
        public
        let code:Int32
        public
        let message:String

        @inlinable public
        init(index:Int, message:String, code:Int32)
        {
            self.index = index
            self.message = message
            self.code = code
        }
    }
}
extension Mongo.WriteError:MongoDecodable
{
    public
    init(bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self.init(index: try bson["index"].decode(to: Int.self),
            message: try bson["errmsg"].decode(to: String.self),
            code: try bson["code"].decode(to: Int32.self))
    }
}
