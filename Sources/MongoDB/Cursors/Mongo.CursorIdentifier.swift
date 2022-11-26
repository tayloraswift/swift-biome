import BSONSchema

extension Mongo
{
    @frozen public
    struct CursorIdentifier:Hashable, RawRepresentable, Sendable
    {
        public
        let rawValue:Int64

        @inlinable public
        init(rawValue:Int64)
        {
            self.rawValue = rawValue
        }
    }
}
extension Mongo.CursorIdentifier
{
    public static
    let none:Self = .init(rawValue: 0)
}
extension Mongo.CursorIdentifier:BSONScheme
{
}
