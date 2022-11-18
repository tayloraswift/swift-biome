import BSON

/// A type that can be converted to a MongoDB document record.
public
protocol MongoEncodable:Sendable
{
    var bson:BSON.Document<[UInt8]> { get }
}
