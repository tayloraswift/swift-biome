import BSON

extension Mongo
{
    /// Drops the current database, deleting its contents.
    ///
    /// > See:  https://docs.mongodb.com/manual/reference/command/dropDatabase
    @frozen public
    struct DropDatabase
    {
        public
        let writeConcern:WriteConcern?

        @inlinable public
        init(writeConcern:WriteConcern? = nil)
        {
            self.writeConcern = writeConcern
        }
    }
}
extension Mongo.DropDatabase:DatabaseCommand
{
    public static
    let node:Mongo.Cluster.Role = .master
    
    public
    var bson:Document
    {
        var bson:Document = 
        [
            "dropDatabase": 1,
        ]
        if let writeConcern:Mongo.WriteConcern = self.writeConcern
        {
            bson.appendValue(writeConcern.bson, forKey: "writeConcern")
        }
        return bson
    }
}
