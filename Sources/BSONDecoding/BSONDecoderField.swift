public
protocol BSONDecoderField<Bytes>
{
    associatedtype Bytes:RandomAccessCollection<UInt8>

    func decode<T>(with decode:(BSON.Value<Bytes>) throws -> T) throws -> T
}
