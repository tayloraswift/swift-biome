import BSONDecoding
import BSONEncoding
import NIOCore

extension Mongo
{
    /// Lists all existing databases along with basic statistics about them. 
    /// This command must run against the `admin` database.
    ///
    /// This command never enables the `nameOnly` option. To enable it, use the
    /// ``ListDatabaseNames`` command.
    ///
    /// > See:  https://www.mongodb.com/docs/manual/reference/command/listDatabases/
    public
    struct ListDatabases
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
extension Mongo.ListDatabases:MongoSessionCommand
{
    public static
    let node:Mongo.InstanceSelector = .any

    public
    var fields:BSON.Fields<[UInt8]>
    {
        [
            "listDatabases": 1,
            "authorizedDatabases": .bool(self.authorizedDatabases),
            "filter": .document(self.filter),
        ]
    }

    public static
    func decode(reply bson:BSON.Dictionary<ByteBufferView>) throws ->
    (
        totalSize:Int,
        databases:[Mongo.Database]
    )
    {
        (
            totalSize: try bson["totalSize"].decode(to: Int.self),
            databases: try bson["databases"].decode(as: BSON.Array<ByteBufferView>.self)
            {
                try $0.map
                {
                    try $0.decode(as: BSON.Dictionary<ByteBufferView>.self,
                        with: Mongo.Database.init(bson:))
                }
            }
        )
    }
}
