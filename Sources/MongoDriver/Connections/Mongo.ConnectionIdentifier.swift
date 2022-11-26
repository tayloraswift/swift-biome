import BSONDecoding

extension Mongo
{
    @frozen public
    struct ConnectionIdentifier:Hashable, RawRepresentable, Sendable
    {
        public
        let rawValue:Int32

        @inlinable public
        init(rawValue:Int32)
        {
            self.rawValue = rawValue
        }
    }
}
extension Mongo.ConnectionIdentifier:CustomStringConvertible
{
    public
    var description:String
    {
        self.rawValue.description
    }
}
extension Mongo.ConnectionIdentifier:BSONDecodable
{
}
