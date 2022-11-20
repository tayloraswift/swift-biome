extension Mongo.Database
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
extension Mongo.Database.ID:ExpressibleByStringLiteral
{
    public static
    let admin:Self = "admin"
    
    @inlinable public
    init(stringLiteral:String)
    {
        self.init(stringLiteral)
    }
}
extension Mongo.Database.ID:CustomStringConvertible
{
    @inlinable public
    var description:String
    {
        self.name
    }
}
