import BSON

/// A type that can be round-tripped to and from a MongoDB document record.
public
protocol MongoRepresentable:MongoDecodable
{
    var bson:BSON.Document<[UInt8]> { get }
}
