extension Mongo
{
    @frozen public
    struct MessageIdentifier:Hashable, Sendable
    {
        public
        let value:Int32

        @inlinable public
        init(_ value:Int32)
        {
            self.value = value
        }
    }
}
extension Mongo.MessageIdentifier
{
    public static
    let none:Self = .init(0)
}
