import BSONSchema

extension Mongo.ReadConcern
{
    @frozen public
    enum Level:String, Hashable, Sendable
    {
        case local
        case available
        case majority
        case linearizable
        case snapshot
    }
}
extension Mongo.ReadConcern.Level:BSONScheme
{
}
