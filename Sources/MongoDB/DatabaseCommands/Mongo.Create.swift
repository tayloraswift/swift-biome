import BSONEncoding

extension Mongo
{
    /// Explicitly creates a collection or view.
    ///
    /// > See:  https://www.mongodb.com/docs/manual/reference/command/create/
    public
    struct Create:Sendable
    {
        public
        let id:Collection.ID
        public
        let options:CollectionOptions

        public
        init(id:Collection.ID, options:CollectionOptions = .init())
        {
            self.id = id
            self.options = options
        }
    }
}
extension Mongo.Create:MongoDatabaseCommand
{
    public static
    let node:Mongo.InstanceSelector = .master
    
    public
    var fields:BSON.Fields<[UInt8]>
    {
        var fields:BSON.Fields<[UInt8]> = self.options.fields
            fields.add(key: "create", value: .string(self.id.name))
        return fields
    }
}
