/// A type that can be encoded to a BSON variant value.
public
protocol BSONEncodable
{
    var bson:BSON.Value<[UInt8]> { get }
}

extension BSONEncodable where Self:BinaryFloatingPoint
{
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .double(Double.init(self))
    }
}

extension Float:BSONEncodable {}
extension Double:BSONEncodable {}
extension Float80:BSONEncodable {}

extension UInt8:BSONEncodable
{
    /// Encodes this integer as a variant of type ``BSON.int32``.
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .int32(Int32.init(self))
    }
}
extension UInt16:BSONEncodable
{
    /// Encodes this integer as a variant of type ``BSON.int32``.
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .int32(Int32.init(self))
    }
}
extension UInt32:BSONEncodable
{
    /// Encodes this integer as a variant of type ``BSON.int64``.
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .int64(Int64.init(self))
    }
}
extension UInt64:BSONEncodable
{
    /// Encodes this integer as a variant of type ``BSON.uint64``.
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .uint64(self)
    }
}
extension UInt:BSONEncodable
{
    /// Encodes this integer as a variant of type ``BSON.uint64``.
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .uint64(UInt64.init(self))
    }
}

extension Int8:BSONEncodable
{
    /// Encodes this integer as a variant of type ``BSON.int32``.
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .int32(Int32.init(self))
    }
}
extension Int16:BSONEncodable
{
    /// Encodes this integer as a variant of type ``BSON.int32``.
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .int32(Int32.init(self))
    }
}
extension Int32:BSONEncodable
{
    /// Encodes this integer as a variant of type ``BSON.int32``.
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .int32(self)
    }
}
extension Int64:BSONEncodable
{
    /// Encodes this integer as a variant of type ``BSON.int64``.
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .int64(self)
    }
}
extension Int:BSONEncodable
{
    /// Encodes this integer as a variant of type ``BSON.int64``.
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .int64(Int64.init(self))
    }
}

extension Bool:BSONEncodable
{
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .bool(self)
    }
}
extension BSON.Decimal128:BSONEncodable
{
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .decimal128(self)
    }
}
extension BSON.Identifier:BSONEncodable
{
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .id(self)
    }
}
extension BSON.Max:BSONEncodable
{
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .max
    }
}
extension BSON.Millisecond:BSONEncodable
{
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .millisecond(self)
    }
}
extension BSON.Min:BSONEncodable
{
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .min
    }
}
extension BSON.Regex:BSONEncodable
{
    /// Encodes this regex as a variant of type ``BSON.regex``.
    /// This method does no computation.
    ///
    /// >   Complexity: O(1).
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .regex(self)
    }
}
extension String:BSONEncodable
{
    /// Encodes this string as a variant of type ``BSON.string``.
    ///
    /// >   Complexity: O(*n*), where *n* is the length of the string.
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .string(self)
    }
}
extension Optional:BSONEncodable where Wrapped:BSONEncodable
{
    /// Encodes this optional as an explicit ``BSON/Value/.null``, if
    /// [`nil`]().
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        self?.bson ?? .null
    }
}

extension Array:BSONEncodable where Element:BSONEncodable
{
    /// Encodes this string as a variant of type ``BSON.string``.
    ///
    /// >   Complexity: O(*n*), where *n* is the length of the string.
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .tuple(.init(self.lazy.map(\.bson)))
    }
}
extension Set:BSONEncodable where Element:BSONEncodable
{
    /// Encodes this string as a variant of type ``BSON.string``.
    ///
    /// >   Complexity: O(*n*), where *n* is the length of the string.
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .tuple(.init(self.lazy.map(\.bson)))
    }
}

extension BSONEncodable where Self:RawRepresentable, RawValue:BSONEncodable
{
    /// Returns the ``bson`` witness of this type’s ``RawRepresentable.rawValue``.
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        self.rawValue.bson
    }
}

extension BSON.Fields:BSONEncodable
{
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .document(.init(self))
    }
}
