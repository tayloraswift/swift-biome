import BSONDecoding
import BSONEncoding
import NIOCore

extension Mongo.Cursor
{
    @frozen public
    struct GetMore
    {
        public
        let collection:Mongo.Collection.ID
        public
        let cursor:Int64
        public
        let batching:Int?
        public
        let timeout:Mongo.Duration?

        @inlinable public
        init?(cursor:Int64, collection:Mongo.Collection.ID,
            batching:Int? = nil,
            timeout:Mongo.Duration? = nil)
        {
            // cursor id of 0 indicates exhaustion
            guard cursor != 0
            else
            {
                return nil
            }
            self.cursor = cursor
            self.collection = collection
            self.batching = batching
            self.timeout = timeout
        }
    }
}
extension Mongo.Cursor.GetMore:MongoDatabaseCommand
{
    public static
    var node:Mongo.InstanceSelector
    {
        .any
    }

    public
    var fields:BSON.Fields<[UInt8]>
    {
        [
            "getMore": .int64(self.cursor),
            "collection": .string(self.collection.name),
            "batchSize": .int64(self.batching.map(Int64.init(_:))),
            "maxTimeMS": .int64(self.timeout?.milliseconds),
        ]
    }

    public
    typealias Response = Mongo.Cursor<Element>
}
