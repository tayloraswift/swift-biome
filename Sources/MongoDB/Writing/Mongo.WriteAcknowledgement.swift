import BSONSchema

extension Mongo
{
    @frozen public
    enum WriteAcknowledgement:Hashable, Sendable
    {
        case majority
        case custom(String)
        case count(Int)
    }
}
extension Mongo.WriteAcknowledgement:BSONEncodable
{
    public
    var bson:BSON.Value<[UInt8]>
    {
        switch self
        {
        case .majority:
            return .string("majority")
        case .custom(let concern):
            return .string(concern)
        case .count(let instances):
            return .int64(Int64.init(instances))
        }
    }
}
extension Mongo.WriteAcknowledgement:BSONDecodable
{
    @inlinable public
    init(bson:BSON.Value<some RandomAccessCollection<UInt8>>) throws
    {
        if case .string(let string) = bson
        {
            let string:String = string.description
            self = string == "majority" ? .majority : .custom(string)
        }
        else if let count:Int = try bson.as(Int.self)
        {
            self = .count(count)
        }
        else
        {
            throw BSON.TypecastError<Self>.init(invalid: bson.type)
        }
    }
}
