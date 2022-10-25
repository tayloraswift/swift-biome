extension Mongo
{
    @frozen public
    struct Database:Hashable, Sendable
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
extension Mongo.Database:ExpressibleByStringLiteral
{
    public static
    let admin:Self = "admin"
    
    @inlinable public
    init(stringLiteral:String)
    {
        self.init(name: stringLiteral)
    }
}
