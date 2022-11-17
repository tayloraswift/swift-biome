extension MongoWire
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
extension MongoWire.MessageIdentifier
{
    public static
    let none:Self = .init(0)
}
extension MongoWire.MessageIdentifier:CustomStringConvertible
{
    public
    var description:String
    {
        self.value.description
    }
}
