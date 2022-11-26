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
        let filter:BSON.Fields

        public
        init(authorizedCollections:Bool? = nil, filter:BSON.Fields = [:])
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
    func encode(to bson:inout BSON.Fields)
    {
        bson["listCollections"] = 1 as Int32
        bson["authorizedCollections"] = self.authorizedCollections
        bson["filter", elide: true] = self.filter
    }

    public
    typealias Response = Mongo.Cursor<Mongo.CollectionMetadata>
}
