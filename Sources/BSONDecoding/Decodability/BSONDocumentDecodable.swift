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
