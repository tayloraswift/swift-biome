extension Mongo
{
    @frozen public
    struct ConnectionIdentifier:Hashable, Sendable
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
extension Mongo.ConnectionIdentifier:CustomStringConvertible
{
    public
    var description:String
    {
        self.value.description
    }
}
