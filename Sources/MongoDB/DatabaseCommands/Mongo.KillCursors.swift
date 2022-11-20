import BSONEncoding

extension Mongo
{
    @frozen public
    struct KillCursors
    {
        public
        let collection:Mongo.Collection.ID
        public
        let cursors:[Int64]

        @inlinable public
        init(_ cursors:[Int64], collection:Mongo.Collection.ID)
        {
            self.collection = collection
            self.cursors = cursors
        }
    }
}
extension Mongo.KillCursors:MongoDatabaseCommand
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
            "cursors": .tuple(.init(self.cursors.map(BSON.Value<[UInt8]>.int64(_:)))),
        ]
    }
}
