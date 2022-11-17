import BSONDecoding
import NIOCore

/// @import(NIOCore)
/// A type that can be decoded from a MongoDB document record.
///
/// This protocol is not a general-purpose BSON decoding interface,
/// because it only accepts ``ByteBufferView``-backed documents.
public
protocol MongoDecodable:Sendable
{
    init(bson document:BSON.Document<ByteBufferView>) throws
}
