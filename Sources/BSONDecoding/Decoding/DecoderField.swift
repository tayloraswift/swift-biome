public
protocol DecoderField<Value>
{
    associatedtype Bytes:RandomAccessCollection<UInt8>
    associatedtype Value

    func decode<T>(with decode:(Value) throws -> T) throws -> T
}
extension DecoderField where Value == BSON.Value<Bytes>
{
    @inlinable public
    func decode<T>(as _:BSON.Array<Bytes.SubSequence>.Type,
        with decode:(BSON.Array<Bytes.SubSequence>) throws -> T) throws -> T
    {
        try self.decode { try decode(try $0.array()) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Dictionary<Bytes.SubSequence>.Type,
        with decode:(BSON.Dictionary<Bytes.SubSequence>) throws -> T) throws -> T
    {
        try self.decode { try decode(try $0.dictionary()) }
    }
    @inlinable public
    func decode<View, T>(as _:View.Type,
        with decode:(View) throws -> T) throws -> T where View:CollectionViewBSON<Bytes>
    {
        try self.decode { try decode(try .init($0)) }
    }
    @inlinable public
    func decode<Decodable, T>(as _:Decodable.Type,
        with decode:(Decodable) throws -> T) throws -> T where Decodable:BSONDecodable
    {
        try self.decode { try decode(try .init(bson: $0)) }
    }
    @inlinable public
    func decode<Decodable>(
        to _:Decodable.Type = Decodable.self) throws -> Decodable where Decodable:BSONDecodable
    {
        try self.decode(with: Decodable.init(bson:))
    }
    @inlinable public
    func decode(to _:Void.Type = Void.self) throws
    {
        try self.decode { try $0.cast(with: \.null) }
    }
}
