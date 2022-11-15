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
        let nameOnly:Bool
        public
        let filter:BSON.Document<[UInt8]>?

        public
        init(authorizedCollections:Bool? = nil,
            nameOnly:Bool = false,
            filter:BSON.Document<[UInt8]>? = nil)
        {
            self.authorizedCollections = authorizedCollections
            self.nameOnly = nameOnly
            self.filter = filter
        }
    }
}
extension Mongo.ListCollections:DatabaseCommand
{
    public static
    let node:Mongo.InstanceSelector = .any

    public
    var fields:BSON.Fields<[UInt8]>
    {
        [
            "listCollections": 1,
            "authorizedCollections": self.authorizedCollections
                .map(BSON.Value<[UInt8]>.bool(_:)),
            "nameOnly": self.nameOnly ? true : nil,
            "filter": self.filter
                .map(BSON.Value<[UInt8]>.document(_:)),
        ]
    }

    public
    typealias Response = Mongo.Cursor
}
