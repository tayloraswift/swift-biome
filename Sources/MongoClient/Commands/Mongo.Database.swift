import BSONEncoding

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
extension Mongo.Database:CustomStringConvertible
{
    @inlinable public
    var description:String
    {
        self.name
    }
}
extension Mongo.Database
{
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .string(self.name)
    }
}

extension BSON.Fields where Bytes:RangeReplaceableCollection
{
    /// Adds a MongoDB database identifier to this list of fields, under the key [`"$db"`]().
    @inlinable public mutating
    func add(database:Mongo.Database)
    {
        self.add(key: "$db", value: .string(database.name))
    }
}
