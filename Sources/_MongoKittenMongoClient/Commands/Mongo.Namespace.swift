extension Mongo
{
    @frozen public
    struct Namespace:Sendable
    {
        public
        let database:Database
        public
        let collection:Collection

        @inlinable public
        init(_ database:Database, _ collection:Collection)
        {
            self.database = database
            self.collection = collection
        }
    }
}
extension Mongo.Namespace:CustomStringConvertible
{
    @inlinable public
    var description:String
    {
        "\(self.database).\(self.collection)"
    }
}
