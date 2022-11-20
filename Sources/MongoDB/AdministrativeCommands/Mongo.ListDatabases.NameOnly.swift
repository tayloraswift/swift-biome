import BSONDecoding
import BSONEncoding
import NIOCore

extension Mongo.ListDatabases
{
    /// Lists the names of all existing databases. 
    /// This command must run against the `admin` database.
    ///
    /// This command always enables the `nameOnly` option. To disable it, use the
    /// ``ListDatabases`` command.
    ///
    /// > See:  https://www.mongodb.com/docs/manual/reference/command/listDatabases/
    public
    struct NameOnly
    {
        public
        let base:Mongo.ListDatabases

        public
        init(_ base:Mongo.ListDatabases)
        {
            self.base = base
        }
    }
}
extension Mongo.ListDatabases.NameOnly
{
    public
    init(authorizedDatabases:Bool? = nil,
        filter:BSON.Document<[UInt8]>? = nil)
    {
        self.init(.init(authorizedDatabases: authorizedDatabases, filter: filter))
    }
}
extension Mongo.ListDatabases.NameOnly:MongoSessionCommand
{
    public static
    let node:Mongo.InstanceSelector = .any

    public
    var fields:BSON.Fields<[UInt8]>
    {
        var fields:BSON.Fields<[UInt8]> = self.base.fields
            fields.add(key: "nameOnly", value: true)
        return fields
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
