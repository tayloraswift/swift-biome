import BSONEncoding

extension Mongo
{
    /// Retrieve information about collections and
    /// [views](https://www.mongodb.com/docs/manual/core/views/) in a database.
    ///
    /// > See:  https://www.mongodb.com/docs/manual/reference/command/listCollections/
    public
    struct ListCollections:Sendable
    {
        public
        let authorizedCollections:Bool?
        public
        let filter:BSON.Document<[UInt8]>?

        public
        init(authorizedCollections:Bool? = nil,
            filter:BSON.Document<[UInt8]>? = nil)
        {
            self.authorizedCollections = authorizedCollections
            self.filter = filter
        }
    }
}
extension Mongo.ListCollections:MongoDatabaseCommand
{
    public static
    let node:Mongo.InstanceSelector = .any

    public
    var fields:BSON.Fields<[UInt8]>
    {
        [
            "listCollections": 1,
            "authorizedCollections": .bool(self.authorizedCollections),
            "filter": .document(self.filter),
        ]
    }

    public
    typealias Response = Mongo.Cursor<Mongo.Collection>
}
