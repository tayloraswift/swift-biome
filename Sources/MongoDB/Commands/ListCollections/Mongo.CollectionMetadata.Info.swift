import BSONDecoding
import UUID

extension Mongo.CollectionMetadata
{
    @frozen public
    struct Info:Sendable
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
extension Mongo.CollectionMetadata.Info:BSONDictionaryDecodable
{
    @inlinable public
    init<Bytes>(bson:BSON.Dictionary<Bytes>) throws
    {
        self.init(readOnly: try bson["readOnly"].decode(to: Bool.self),
            uuid: try bson["uuid"].decode(as: BSON.Binary<Bytes>.self) { .init($0.bytes) })
    }
}
