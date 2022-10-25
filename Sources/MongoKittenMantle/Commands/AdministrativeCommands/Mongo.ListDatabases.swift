import BSON
import MongoClient

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
        let filter:Document?

        @inlinable public
        init(writeConcern:WriteConcern? = nil,
            authorizedDatabases:Bool? = nil,
            nameOnly:Bool = false,
            filter:Document? = nil)
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
    let node:Mongo.Cluster.Role = .any

    public
    var bson:Document
    {
        var bson:Document = 
        [
            "listDatabases": 1,
        ]
        if let writeConcern:Mongo.WriteConcern = self.writeConcern
        {
            bson.appendValue(writeConcern.bson, forKey: "writeConcern")
        }
        if let authorizedDatabases:Bool = self.authorizedDatabases
        {
            bson.appendValue(authorizedDatabases, forKey: "authorizedDatabases")
        }
        if self.nameOnly
        {
            bson.appendValue(true, forKey: "nameOnly")
        }
        if let filter:Document = self.filter
        {
            bson.appendValue(filter, forKey: "filter")
        }
        return bson
    }

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

        init(from bson:any Primitive) throws
        {
            guard let bson:Document = bson as? Document
            else
            {
                throw _BSONDecodingError.init()
            }

            self.sizeOnDisk = bson["sizeOnDisk"] as? Int
            
            guard let name:String = bson["name"] as? String
            else
            {
                throw _BSONDecodingError.init()
            }
            self.database = .init(name: name)
        }
    }
    @frozen public
    struct Items
    {
        public
        let totalSize:Int?
        public
        let databases:[Item]

        init(from bson:Document) throws
        {
            self.totalSize = bson["totalSize"] as? Int
            
            if let databases:Document = bson["databases"] as? Document
            {
                self.databases = try databases.values.map(Item.init(from:))
            }
            else
            {
                throw _BSONDecodingError.init()
            }
        }
    }

    public static
    func decode(reply:OpMessage) throws -> Items
    {
        guard let document:Document = reply.first
        else
        {
            throw MongoCommandError.emptyReply
        }

        try document.status()

        return try .init(from: document)
    }
}