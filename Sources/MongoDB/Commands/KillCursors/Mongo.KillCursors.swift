import BSONEncoding

extension Mongo
{
    @frozen public
    struct KillCursors:Sendable
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
    func encode(to bson:inout BSON.Fields)
    {
        bson["killCursors"] = self.collection
        bson["cursors"] = self.cursors
    }
}
