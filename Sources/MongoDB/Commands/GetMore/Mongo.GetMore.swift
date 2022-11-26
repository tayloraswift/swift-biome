import MongoSchema

extension Mongo
{
    @frozen public
    struct GetMore<Element> where Element:MongoDecodable
    {
        public
        let collection:Collection
        public
        let cursor:CursorIdentifier
        public
        let batching:Int?
        public
        let timeout:Milliseconds?

        @inlinable public
        init?(cursor:CursorIdentifier, collection:Collection,
            batching:Int? = nil,
            timeout:Milliseconds? = nil)
        {
            // cursor id of 0 indicates exhaustion
            guard cursor != .none
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
extension Mongo.GetMore:MongoDatabaseCommand
{
    public static
    var node:Mongo.InstanceSelector
    {
        .any
    }

    public
    func encode(to bson:inout BSON.Fields)
    {
        bson["getMore"] = self.cursor
        bson["collection"] = self.collection
        bson["batchSize"] = self.batching
        bson["maxTimeMS"] = self.timeout
    }

    public
    typealias Response = Mongo.Cursor<Element>
}
