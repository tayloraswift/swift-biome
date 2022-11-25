/// A type that can be decoded from a BSON array-decoder.
public
protocol BSONArrayDecodable:BSONDecodable
{
    init(bson:BSON.Array<some RandomAccessCollection<UInt8>>) throws
}
extension BSONArrayDecodable
{
    @inlinable public
    init<Bytes>(bson:BSON.Value<Bytes>) throws
    {
        try self.init(bson: try bson.array())
    }
}

extension Array:BSONArrayDecodable, BSONDecodable where Element:BSONDecodable
{
    @inlinable public
    init<Bytes>(bson:BSON.Array<Bytes>) throws
    {
        self = try bson.map { try $0.decode(to: Element.self) }
    }
}
extension Set:BSONArrayDecodable, BSONDecodable where Element:BSONDecodable
{
    @inlinable public
    init<Bytes>(bson:BSON.Array<Bytes>) throws
    {
        self.init(try bson.lazy.map { try $0.decode(to: Element.self) })
    }
}
