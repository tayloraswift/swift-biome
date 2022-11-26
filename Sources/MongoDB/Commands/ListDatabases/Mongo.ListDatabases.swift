import BSONDecoding
import BSONEncoding

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
    struct ListDatabases:Sendable
    {
        public
        let authorizedDatabases:Bool?
        public
        let filter:BSON.Fields

        public
        init(authorizedDatabases:Bool? = nil, filter:BSON.Fields = [:])
        {
            self.authorizedDatabases = authorizedDatabases
            self.filter = filter
        }
    }
}
extension Mongo.ListDatabases:MongoImplicitSessionCommand
{
    public
    typealias Response =
    (
        totalSize:Int,
        databases:[Mongo.DatabaseMetadata]
    )

    public static
    let node:Mongo.InstanceSelector = .any

    public
    func encode(to bson:inout BSON.Fields)
    {
        bson["listDatabases"] = 1 as Int32
        bson["authorizedDatabases"] = self.authorizedDatabases
        bson["filter", elide: true] = self.filter
    }

    public static
    func decode<Bytes>(reply bson:BSON.Dictionary<Bytes>) throws -> Response
    {
        (
            totalSize: try bson["totalSize"].decode(to: Int.self),
            databases: try bson["databases"].decode(to: [Mongo.DatabaseMetadata].self)
        )
    }
}
