import BSONEncoding

extension Mongo
{
    /// Drops the current database, deleting its contents.
    ///
    /// > See:  https://docs.mongodb.com/manual/reference/command/dropDatabase
    public
    struct DropDatabase
    {
        public
        let writeConcern:WriteConcern?

        public
        init(writeConcern:WriteConcern? = nil)
        {
            self.writeConcern = writeConcern
        }
    }
}
extension Mongo.DropDatabase:MongoDatabaseCommand, MongoImplicitSessionCommand
{
    public static
    let node:Mongo.InstanceSelector = .master

    public
    var fields:BSON.Fields<[UInt8]>
    {
        [
            "dropDatabase": 1,
            "writeConcern": .document(self.writeConcern?.bson),
        ]
    }
}
