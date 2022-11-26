/// A type that can be decoded from a BSON document. Tuple-documents
/// count as documents, from the perspective of this protocol.
public
protocol BSONDocumentDecodable:BSONDecodable
{
    init(bson:BSON.Document<some RandomAccessCollection<UInt8>>) throws
}
extension BSONDocumentDecodable
{
    @inlinable public
    init<Bytes>(bson:BSON.Value<Bytes>) throws
    {
        try self.init(bson: try BSON.Document<Bytes>.init(bson))
    }
}
extension BSON.Fields:BSONDocumentDecodable
{
    /// Creates an encoding view around the given generic document,
    /// copying its backing storage if it is not already backed by
    /// a native Swift array.
    ///
    /// If the document is already backed by a Swift array, this
    /// initializer will only be called in dynamic contexts, because
    /// overload resolution will prefer the non-generic ``init(bson:)``
    /// overload.
    ///
    /// >   Complexity:
    ///     O(1) if the opaque type is [`[UInt8]`](), O(*n*) otherwise,
    ///     where *n* is the encoded size of the document.
    @inlinable public
    init(bson:BSON.Document<some RandomAccessCollection<UInt8>>) throws
    {
        switch bson
        {
        case let bson as BSON.Document<[UInt8]>:
            self.init(bson: bson)
        case let bson:
            self.init(output: .init(preallocated: [UInt8].init(bson.bytes)))
        }
    }
}
