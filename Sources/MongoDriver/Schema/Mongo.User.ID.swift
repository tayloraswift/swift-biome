import BSON

extension Mongo
{
    public
    enum User
    {
    }
}
extension Mongo.User
{
    @frozen public
    struct ID:Sendable
    {
        public
        let database:Mongo.Database.ID
        public
        let name:String

        @inlinable public
        init(_ database:Mongo.Database.ID, _ name:String)
        {
            self.database = database
            self.name = name
        }
    }
}
extension Mongo.User.ID:CustomStringConvertible
{
    @inlinable public
    var description:String
    {
        "\(self.database).\(self.name)"
    }
}
extension Mongo.User.ID
{
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .string(self.description)
    }
}
