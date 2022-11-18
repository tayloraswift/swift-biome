import BSONDecoding
import NIOCore

extension Mongo
{
    public
    struct InsertResponse:Equatable, Sendable
    {
        public
        let writeConcernErrors:[Mongo.WriteConcernError]
        public
        let writeErrors:[Mongo.WriteError]
        public
        let inserted:Int

        public
        init(inserted:Int,
            writeConcernErrors:[Mongo.WriteConcernError] = [],
            writeErrors:[Mongo.WriteError] = [])
        {
            self.writeConcernErrors = writeConcernErrors
            self.writeErrors = writeErrors
            self.inserted = inserted
        }
    }
}
extension Mongo.InsertResponse:MongoDecodable
{
    public
    init(bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self.init(inserted: try bson["n"].decode(to: Int.self),
            writeConcernErrors: try bson["writeConcernErrors"]?.decode(
                as: BSON.Array<ByteBufferView>.self)
            {
                try $0.map
                { 
                    try $0.decode(as: BSON.Dictionary<ByteBufferView>.self,
                        with: Mongo.WriteConcernError.init(bson:))
                }
            } ?? [],
            writeErrors: try bson["writeErrors"]?.decode(
                as: BSON.Array<ByteBufferView>.self)
            {
                try $0.map
                {
                    try $0.decode(as: BSON.Dictionary<ByteBufferView>.self,
                        with: Mongo.WriteError.init(bson:))
                }
            } ?? [])
    }
}
