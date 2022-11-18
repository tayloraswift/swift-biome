extension Mongo.Collection
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
extension Mongo.Collection.ID:ExpressibleByStringLiteral
{
    @inlinable public
    init(stringLiteral:String)
    {
        self.init(stringLiteral)
    }
}
extension Mongo.Collection.ID:CustomStringConvertible
{
    @inlinable public
    var description:String
    {
        self.name
    }
}
