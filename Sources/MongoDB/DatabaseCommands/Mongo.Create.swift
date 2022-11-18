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
        let collection:Collection.ID
        public
        let options:CollectionOptions

        public
        init(collection:Collection.ID, options:CollectionOptions = .init())
        {
            self.collection = collection
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
            fields.add(key: "create", value: .string(self.collection.name))
        return fields
    }
}
