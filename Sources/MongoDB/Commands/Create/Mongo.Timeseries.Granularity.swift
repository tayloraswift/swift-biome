import BSONSchema

extension Mongo.Timeseries
{
    @frozen public
    enum Granularity:String, Hashable, Sendable
    {
        case seconds
        case minutes
        case hours
    }
}
extension Mongo.Timeseries.Granularity:BSONScheme
{
}
