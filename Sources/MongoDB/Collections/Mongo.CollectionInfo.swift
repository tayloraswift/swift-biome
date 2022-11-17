import BSONDecoding
import NIOCore
import UUID

extension Mongo
{
    @frozen public
    struct CollectionInfo:Sendable
    {
        public
        let readOnly:Bool
        public
        let uuid:UUID

        @inlinable public
        init(readOnly:Bool, uuid:UUID)
        {
            self.readOnly = readOnly
            self.uuid = uuid
        }
    }
}
extension Mongo.CollectionInfo:MongoScheme
{
    public
    init(bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self.init(readOnly: try bson["readOnly"].decode(to: Bool.self),
            uuid: try bson["uuid"].decode(as: BSON.Binary<ByteBufferView>.self)
            {
                .init($0.bytes)
            })
    }
}
