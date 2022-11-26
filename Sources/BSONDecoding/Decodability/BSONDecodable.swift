/// A type that can be decoded from a BSON variant value.
public
protocol BSONDecodable
{
    init(bson:BSON.Value<some RandomAccessCollection<UInt8>>) throws
}

extension Bool:BSONDecodable
{
    @inlinable public
    init(bson:BSON.Value<some RandomAccessCollection<UInt8>>) throws
    {
        self = try bson.cast { $0.as(Self.self) }
    }
}
extension BSON.Decimal128:BSONDecodable
{
    @inlinable public
    init(bson:BSON.Value<some RandomAccessCollection<UInt8>>) throws
    {
        self = try bson.cast { $0.as(Self.self) }
    }
}
extension BSON.Identifier:BSONDecodable
{
    @inlinable public
    init(bson:BSON.Value<some RandomAccessCollection<UInt8>>) throws
    {
        self = try bson.cast { $0.as(Self.self) }
    }
}
extension BSON.Max:BSONDecodable
{
    @inlinable public
    init(bson:BSON.Value<some RandomAccessCollection<UInt8>>) throws
    {
        self = try bson.cast(with: \.max)
    }
}
extension BSON.Millisecond:BSONDecodable
{
    @inlinable public
    init(bson:BSON.Value<some RandomAccessCollection<UInt8>>) throws
    {
        self = try bson.cast { $0.as(Self.self) }
    }
}
extension BSON.Min:BSONDecodable
{
    @inlinable public
    init(bson:BSON.Value<some RandomAccessCollection<UInt8>>) throws
    {
        self = try bson.cast(with: \.min)
    }
}
extension BSON.Regex:BSONDecodable
{
    @inlinable public
    init(bson:BSON.Value<some RandomAccessCollection<UInt8>>) throws
    {
        self = try bson.cast { $0.as(Self.self) }
    }
}
extension String:BSONDecodable
{
    @inlinable public
    init(bson:BSON.Value<some RandomAccessCollection<UInt8>>) throws
    {
        self = try bson.cast { $0.as(Self.self) }
    }
}

extension UInt8:BSONDecodable {}
extension UInt16:BSONDecodable {}
extension UInt32:BSONDecodable {}
extension UInt64:BSONDecodable {}
extension UInt:BSONDecodable {}

extension Int8:BSONDecodable {}
extension Int16:BSONDecodable {}
extension Int32:BSONDecodable {}
extension Int64:BSONDecodable {}
extension Int:BSONDecodable {}

extension Float:BSONDecodable {}
extension Double:BSONDecodable {}
extension Float80:BSONDecodable {}

extension BSONDecodable where Self:FixedWidthInteger
{
    @inlinable public
    init(bson:BSON.Value<some RandomAccessCollection<UInt8>>) throws
    {
        self = try bson.cast { try $0.as(Self.self) }
    }
}
extension BSONDecodable where Self:BinaryFloatingPoint
{
    @inlinable public
    init(bson:BSON.Value<some RandomAccessCollection<UInt8>>) throws
    {
        self = try bson.cast { $0.as(Self.self) }
    }
}
extension BSONDecodable where Self:RawRepresentable, RawValue:BSONDecodable
{
    @inlinable public
    init(bson:BSON.Value<some RandomAccessCollection<UInt8>>) throws
    {
        let rawValue:RawValue = try .init(bson: bson)
        if  let value:Self = .init(rawValue: rawValue)
        {
            self = value
        }
        else 
        {
            throw BSON.ValueError<RawValue, Self>.init(invalid: rawValue)
        }
    }
}

extension Optional:BSONDecodable where Wrapped:BSONDecodable
{
    @inlinable public
    init(bson:BSON.Value<some RandomAccessCollection<UInt8>>) throws
    {
        if case .null = bson 
        {
            self = .none 
        }
        else
        {
            self = .some(try .init(bson: bson))
        }
    }
}
