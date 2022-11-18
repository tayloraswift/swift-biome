extension Mongo
{
    @frozen public
    struct Namespace:Hashable, Sendable
    {
        public
        let database:Database.ID
        public
        let collection:Collection.ID

        @inlinable public
        init(_ database:Database.ID, _ collection:Collection.ID)
        {
            self.database = database
            self.collection = collection
        }
    }
}
extension Mongo.Namespace
{
    @inlinable public
    init(parsing string:some StringProtocol) throws
    {
        if let separator:String.Index = string.firstIndex(of: ".")
        {
            self.init(
                .init(String.init(string.prefix(upTo: separator))),
                .init(String.init(string.suffix(from: string.index(after: separator)))))
        }
        else
        {
            throw Mongo.NamespaceError.init(invalid: .init(string))
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
