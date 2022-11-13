import BSONDecoding
import BSONEncoding
import MongoClient
import NIOCore

extension Mongo
{
    /// Lists all existing databases along with basic statistics about them. 
    /// This command must run against the `admin` database.
    ///
    /// > See:  https://www.mongodb.com/docs/manual/reference/command/listDatabases/
    @frozen public
    struct ListDatabases
    {
        public
        let writeConcern:WriteConcern?
        public
        let authorizedDatabases:Bool?
        public
        let nameOnly:Bool
        public
        let filter:BSON.Document<[UInt8]>?

        @inlinable public
        init(writeConcern:WriteConcern? = nil,
            authorizedDatabases:Bool? = nil,
            nameOnly:Bool = false,
            filter:BSON.Document<[UInt8]>? = nil)
        {
            self.writeConcern = writeConcern
            self.authorizedDatabases = authorizedDatabases
            self.nameOnly = nameOnly
            self.filter = filter
        }
    }
}
extension Mongo.ListDatabases:AdministrativeCommand
{
    public static
    let node:Mongo.InstanceSelector = .any

    public
    var fields:BSON.Fields<[UInt8]>
    {
        [
            "listDatabases": 1,
            "writeConcern": self.writeConcern?.bson,
            "authorizedDatabases": self.authorizedDatabases
                .map(BSON.Value<[UInt8]>.bool(_:)),
            "nameOnly": self.nameOnly ? true : nil,
            "filter": self.filter
                .map(BSON.Value<[UInt8]>.document(_:)),
        ]
    }

    @frozen public
    struct Response
    {
        public
        let totalSize:Int?
        public
        let databases:[Item]
    }
}
extension Mongo.ListDatabases.Response:MongoResponse
{
    public
    init(from bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self.totalSize = try bson["totalSize"]?.decode(to: Int.self)
        self.databases = try bson["databases"].decode(as: BSON.Array<ByteBufferView>.self)
        {
            try $0.map
            {
                try $0.decode(as: BSON.Dictionary<ByteBufferView>.self, with: Item.init(from:))
            }
        }
    }
}
extension Mongo.ListDatabases.Response
{
    @frozen public
    struct Item
    {
        public
        let database:Mongo.Database
        public
        let sizeOnDisk:Int?

        @inlinable public
        var name:String
        {
            self.database.name
        }
    }
}
extension Mongo.ListDatabases.Response.Item
{
    init(from bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self.sizeOnDisk = try bson["sizeOnDisk"]?.decode(to: Int.self)
        self.database = try bson["name"].decode(as: String.self,
            with: Mongo.Database.init(name:))
    }
}
