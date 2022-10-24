extension Mongo
{
    @frozen public
    struct Collection
    {
        public
        let name:String

        @inlinable public
        init(name:String)
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
        self.init(name: stringLiteral)
    }
}
