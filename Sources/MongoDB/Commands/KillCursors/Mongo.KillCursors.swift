import BSONEncoding

extension Mongo
{
    @frozen public
    struct KillCursors
    {
        public
        let collection:Collection
        public
        let cursors:[CursorIdentifier]

        @inlinable public
        init(_ cursors:[CursorIdentifier], collection:Collection)
        {
            self.collection = collection
            self.cursors = cursors
        }
    }
}
extension Mongo.KillCursors:MongoDatabaseCommand, MongoSessionCommand
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
            "killCursors": .string(self.collection.name),
            "cursors": .tuple(.init(self.cursors.lazy.map
            { 
                BSON.Value<[UInt8]>.int64($0.rawValue) 
            })),
        ]
    }
}
