extension Mongo
{
    @frozen public
    struct User:Sendable
    {
        public
        let database:Database
        public
        let name:String

        @inlinable public
        init(_ database:Database, _ name:String)
        {
            self.database = database
            self.name = name
        }
    }
}
extension Mongo.User:CustomStringConvertible
{
    @inlinable public
    var description:String
    {
        "\(self.database).\(self.name)"
    }
}
