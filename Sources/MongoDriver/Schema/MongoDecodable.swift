import BSONDecoding
import NIOCore

/// @import(NIOCore)
/// A type that can be decoded from a uniquely-keyed MongoDB
/// document record.
///
/// This protocol is not a general-purpose BSON decoding interface,
/// because it only accepts uniquely-keyed ``ByteBufferView``-backed
/// documents. MongoDB explicitly
/// [does not support](https://www.mongodb.com/docs/manual/reference/limits/#naming-warnings)
/// BSON documents with duplicate field keys.
public
protocol MongoDecodable:Sendable
{
    init(bson dictionary:BSON.Dictionary<ByteBufferView>) throws
}
extension MongoDecodable
{
    /// Attempts to parse and uniqueify the fields in the given document,
    /// and forwards it to this type’s ``init(bson:)`` witness.
    @inlinable public
    init(bson document:BSON.Document<ByteBufferView>) throws
    {
        try self.init(bson: try .init(fields: try document.parse()))
    }
}
