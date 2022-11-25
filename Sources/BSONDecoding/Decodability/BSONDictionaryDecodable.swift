/// A type that can be decoded from a BSON dictionary-decoder.
public
protocol BSONDictionaryDecodable:BSONDocumentDecodable
{
    init(bson:BSON.Dictionary<some RandomAccessCollection<UInt8>>) throws
}
extension BSONDictionaryDecodable
{
    @inlinable public
    init<Bytes>(bson:BSON.Document<Bytes>) throws
    {
        try self.init(bson: try .init(fields: try bson.parse()))
    }
}
