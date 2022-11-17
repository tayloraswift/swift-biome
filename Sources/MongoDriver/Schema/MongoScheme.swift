import BSONDecoding
import NIOCore

/// A type that can be decoded from a uniquely-keyed MongoDB
/// document record.
public
protocol MongoScheme:MongoDecodable
{
    init(bson dictionary:BSON.Dictionary<ByteBufferView>) throws
}
extension MongoScheme
{
    /// Attempts to parse and uniqueify the fields in the given document,
    /// and forwards it to this type’s ``init(bson:)`` witness.
    @inlinable public
    init(bson document:BSON.Document<ByteBufferView>) throws
    {
        try self.init(bson: try .init(fields: try document.parse()))
    }
}
