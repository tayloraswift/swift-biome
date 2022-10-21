import BSON

extension MongoDB
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
extension MongoDB.ListDatabases:MongoAdministrativeCommand
{
    public
    var bson:Document
    {
        var bson:Document = 
        [
            "listDatabases": 1,
        ]
        if let writeConcern:MongoDB.WriteConcern = self.writeConcern
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
}