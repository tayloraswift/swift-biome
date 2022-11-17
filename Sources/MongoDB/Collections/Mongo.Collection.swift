import BSONDecoding
import NIOCore

extension Mongo
{
    @frozen public
    struct Collection:Identifiable, Sendable
    {
        public
        let id:ID
        public
        let type:CollectionType
        public
        let options:CollectionOptions
        public
        let info:CollectionInfo

        @inlinable public
        init(id:ID, type:CollectionType, options:CollectionOptions, info:CollectionInfo)
        {
            self.id = id
            self.type = type
            self.options = options
            self.info = info
        }
    }
}
extension Mongo.Collection:MongoScheme
{
    public
    init(bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self.init(id: try bson["name"].decode(as: String.self, with: ID.init(_:)),
            type: try bson["type"].decode(cases: Mongo.CollectionType.self),
            options: try bson["options"].decode(
                as: BSON.Dictionary<ByteBufferView>.self,
                with: Mongo.CollectionOptions.init(bson:)),
            info: try bson["info"].decode(
                as: BSON.Dictionary<ByteBufferView>.self,
                with: Mongo.CollectionInfo.init(bson:)))
    }
}