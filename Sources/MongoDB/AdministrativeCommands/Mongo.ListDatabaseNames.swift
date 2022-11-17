import BSONDecoding
import BSONEncoding
import NIOCore

extension Mongo
{
    /// Lists the names of all existing databases. 
    /// This command must run against the `admin` database.
    ///
    /// This command always enables the `nameOnly` option. To disable it, use the
    /// ``ListDatabases`` command.
    ///
    /// > See:  https://www.mongodb.com/docs/manual/reference/command/listDatabases/
    public
    struct ListDatabaseNames
    {
        public
        let authorizedDatabases:Bool?
        public
        let filter:BSON.Document<[UInt8]>?

        public
        init(authorizedDatabases:Bool? = nil,
            filter:BSON.Document<[UInt8]>? = nil)
        {
            self.authorizedDatabases = authorizedDatabases
            self.filter = filter
        }
    }
}
extension Mongo.ListDatabaseNames:MongoSessionCommand
{
    public static
    let node:Mongo.InstanceSelector = .any

    public
    var fields:BSON.Fields<[UInt8]>
    {
        [
            "listDatabases": 1,
            "authorizedDatabases": .bool(self.authorizedDatabases),
            "nameOnly": true,
            "filter": .document(self.filter),
        ]
    }

    public static
    func decode(reply bson:BSON.Dictionary<ByteBufferView>) throws -> [Mongo.Database.ID]
    {
        try bson["databases"].decode(as: BSON.Array<ByteBufferView>.self)
        {
            try $0.map
            {
                try $0.decode(as: BSON.Dictionary<ByteBufferView>.self)
                {
                    try $0["name"].decode(as: String.self, with: Mongo.Database.ID.init(_:))
                }
            }
        }
    }
}
