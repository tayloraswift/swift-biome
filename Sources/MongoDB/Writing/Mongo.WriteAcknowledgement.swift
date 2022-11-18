import BSONDecoding

extension Mongo
{
    @frozen public
    enum WriteAcknowledgement:Hashable, Sendable
    {
        case majority
        case count(Int)
        case custom(String)
    }
}
extension Mongo.WriteAcknowledgement
{
    init(bson:BSON.Value<some RandomAccessCollection<UInt8>>) throws
    {
        if case .string(let string) = bson
        {
            let string:String = string.description
            self = string == "majority" ? .majority : .custom(string)
        }
        else
        {
            self = .count(try bson.as(Int.self))
        }
    }

    var bson:BSON.Value<[UInt8]>
    {
        switch self
        {
        case .majority:
            return "majority"
        case .count(let instances):
            return .int64(Int64.init(instances))
        case .custom(let concern):
            return .string(concern)
        }
    }
}
