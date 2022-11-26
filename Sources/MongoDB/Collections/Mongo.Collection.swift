import BSONSchema

extension Mongo
{
    @frozen public
    struct Collection:Hashable, Sendable
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
extension Mongo.Collection:ExpressibleByStringLiteral
{
    @inlinable public
    init(stringLiteral:String)
    {
        self.init(stringLiteral)
    }
}
extension Mongo.Collection:LosslessStringConvertible
{
    @inlinable public
    var description:String
    {
        self.name
    }
}
extension Mongo.Collection:BSONStringScheme
{
}
