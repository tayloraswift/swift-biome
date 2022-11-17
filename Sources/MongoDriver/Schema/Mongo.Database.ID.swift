import BSONEncoding

extension Mongo.Database
{
    @frozen public
    struct ID:Hashable, Sendable
    {
        public
        let name:String

        @inlinable public
        init(_ name:String)
        {
            self.name = name
        }
    }
}
extension Mongo.Database.ID:ExpressibleByStringLiteral
{
    public static
    let admin:Self = "admin"
    
    @inlinable public
    init(stringLiteral:String)
    {
        self.init(stringLiteral)
    }
}
extension Mongo.Database.ID:CustomStringConvertible
{
    @inlinable public
    var description:String
    {
        self.name
    }
}
extension Mongo.Database.ID
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
    func add(database:Mongo.Database.ID)
    {
        self.add(key: "$db", value: .string(database.name))
    }
}
