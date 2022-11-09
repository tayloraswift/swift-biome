import BSON

extension Mongo
{
    @frozen public
    struct Database:Hashable, Sendable
    {
        public
        let name:String

        @inlinable public
        init(name:String)
        {
            self.name = name
        }
    }
}
extension Mongo.Database:ExpressibleByStringLiteral
{
    public static
    let admin:Self = "admin"
    
    @inlinable public
    init(stringLiteral:String)
    {
        self.init(name: stringLiteral)
    }
}

extension BSON.Fields where Bytes:RangeReplaceableCollection
{
    /// Adds a MongoDB database identifier to this list of fields, under the key [`"$db"`]().
    mutating
    func add(database:Mongo.Database)
    {
        self.add(key: "$db", value: .string(database.name))
    }
}
