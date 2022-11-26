import BSONSchema

extension Mongo
{
    @frozen public
    struct Namespaced<Name> where Name:LosslessStringConvertible
    {
        public
        let database:Database
        public
        let name:Name

        @inlinable public
        init(_ database:Database, _ name:Name)
        {
            self.database = database
            self.name = name
        }
    }
}
extension Mongo.Namespaced:Sendable where Name:Sendable
{
}
extension Mongo.Namespaced:Equatable where Name:Equatable
{
}
extension Mongo.Namespaced:Hashable where Name:Hashable
{
}
extension Mongo.Namespaced:LosslessStringConvertible
{
    @inlinable public
    init?(_ string:some StringProtocol)
    {
        if  let separator:String.Index = string.firstIndex(of: "."),
            let name:Name = .init(String.init(string.suffix(
                from: string.index(after: separator))))
        {
            self.init(.init(String.init(string.prefix(upTo: separator))), name)
        }
        else
        {
            return nil
        }
    }
    @inlinable public
    var description:String
    {
        "\(self.database).\(self.name)"
    }
}
extension Mongo.Namespaced:BSONStringScheme
{
}
