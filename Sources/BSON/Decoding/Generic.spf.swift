

extension BSON.Value
{
    @inlinable public 
    func `as`<Integer>(_:Integer.Type) throws -> Integer
        where Integer:FixedWidthInteger
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`<Integer>(_:Integer?.Type) throws -> Integer? 
        where Integer:FixedWidthInteger
    {
        try self.flatMatch(Self.as(_:))
    }
}

extension BSON.Value
{
    @inlinable public 
    func `as`<Binary>(_:Binary.Type) throws -> Binary
        where Binary:BinaryFloatingPoint
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`<Binary>(_:Binary?.Type) throws -> Binary? 
        where Binary:BinaryFloatingPoint
    {
        try self.flatMatch(Self.as(_:))
    }
}

extension BSON.Array
{
    @inlinable public
    func decode<Integer>(_ index:Int,
        as _:Integer.Type = Integer.self) throws -> Integer
        where Integer:FixedWidthInteger
    {
        try self.decode(index) { try $0.as(Integer.self) }
    }
    @inlinable public
    func decode<Integer>(_ index:Int,
        as _:Integer?.Type = Integer?.self) throws -> Integer?
        where Integer:FixedWidthInteger
    {
        try self.decode(index) { try $0.as(Integer?.self) }
    }
}

extension BSON.Array
{
    @inlinable public
    func decode<Binary>(_ index:Int,
        as _:Binary.Type = Binary.self) throws -> Binary
        where Binary:BinaryFloatingPoint
    {
        try self.decode(index) { try $0.as(Binary.self) }
    }
    @inlinable public
    func decode<Binary>(_ index:Int,
        as _:Binary?.Type = Binary?.self) throws -> Binary?
        where Binary:BinaryFloatingPoint
    {
        try self.decode(index) { try $0.as(Binary?.self) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<Integer>(_ key:String,
        as _:Integer.Type = Integer.self) throws -> Integer
        where Integer:FixedWidthInteger
    {
        try self.decode(key) { try $0.as(Integer.self) }
    }
    @inlinable public
    func decode<Integer>(_ key:String,
        as _:Integer?.Type = Integer?.self) throws -> Integer?
        where Integer:FixedWidthInteger
    {
        try self.decode(key) { try $0.as(Integer?.self) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<Binary>(_ key:String,
        as _:Binary.Type = Binary.self) throws -> Binary
        where Binary:BinaryFloatingPoint
    {
        try self.decode(key) { try $0.as(Binary.self) }
    }
    @inlinable public
    func decode<Binary>(_ key:String,
        as _:Binary?.Type = Binary?.self) throws -> Binary?
        where Binary:BinaryFloatingPoint
    {
        try self.decode(key) { try $0.as(Binary?.self) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<Integer>(mapping key:String,
        as _:Integer.Type = Integer.self) throws -> Integer?
        where Integer:FixedWidthInteger
    {
        try self.decode(mapping: key) { try $0.as(Integer.self) }
    }
    @inlinable public
    func decode<Integer>(mapping key:String,
        as _:Integer?.Type = Integer?.self) throws -> Integer?
        where Integer:FixedWidthInteger
    {
        try self.decode(mapping: key) { try $0.as(Integer?.self) } ?? nil
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<Binary>(mapping key:String,
        as _:Binary.Type = Binary.self) throws -> Binary?
        where Binary:BinaryFloatingPoint
    {
        try self.decode(mapping: key) { try $0.as(Binary.self) }
    }
    @inlinable public
    func decode<Binary>(mapping key:String,
        as _:Binary?.Type = Binary?.self) throws -> Binary?
        where Binary:BinaryFloatingPoint
    {
        try self.decode(mapping: key) { try $0.as(Binary?.self) } ?? nil
    }
}

extension BSON.Array
{
    @inlinable public
    func decode<Integer, T>(_ index:Int,
        as _:Integer.Type,
        with decode:(Integer) throws -> T) throws -> T
        where Integer:FixedWidthInteger
    {
        try self.decode(index) { try decode(try $0.as(Integer.self)) }
    }
    @inlinable public
    func decode<Integer, T>(_ index:Int,
        as _:Integer?.Type,
        with decode:(Integer) throws -> T) throws -> T?
        where Integer:FixedWidthInteger
    {
        try self.decode(index) { try $0.as(Integer?.self).map(decode) }
    }
}

extension BSON.Array
{
    @inlinable public
    func decode<Binary, T>(_ index:Int,
        as _:Binary.Type,
        with decode:(Binary) throws -> T) throws -> T
        where Binary:BinaryFloatingPoint
    {
        try self.decode(index) { try decode(try $0.as(Binary.self)) }
    }
    @inlinable public
    func decode<Binary, T>(_ index:Int,
        as _:Binary?.Type,
        with decode:(Binary) throws -> T) throws -> T?
        where Binary:BinaryFloatingPoint
    {
        try self.decode(index) { try $0.as(Binary?.self).map(decode) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<Integer, T>(_ key:String,
        as _:Integer.Type,
        with decode:(Integer) throws -> T) throws -> T
        where Integer:FixedWidthInteger
    {
        try self.decode(key) { try decode(try $0.as(Integer.self)) }
    }
    @inlinable public
    func decode<Integer, T>(_ key:String,
        as _:Integer?.Type,
        with decode:(Integer) throws -> T) throws -> T?
        where Integer:FixedWidthInteger
    {
        try self.decode(key) { try $0.as(Integer?.self).map(decode) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<Binary, T>(_ key:String,
        as _:Binary.Type,
        with decode:(Binary) throws -> T) throws -> T
        where Binary:BinaryFloatingPoint
    {
        try self.decode(key) { try decode(try $0.as(Binary.self)) }
    }
    @inlinable public
    func decode<Binary, T>(_ key:String,
        as _:Binary?.Type,
        with decode:(Binary) throws -> T) throws -> T?
        where Binary:BinaryFloatingPoint
    {
        try self.decode(key) { try $0.as(Binary?.self).map(decode) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<Integer, T>(mapping key:String,
        as _:Integer.Type,
        with decode:(Integer) throws -> T) throws -> T?
        where Integer:FixedWidthInteger
    {
        try self.decode(mapping: key) { try decode(try $0.as(Integer.self)) }
    }
    @inlinable public
    func decode<Integer, T>(mapping key:String,
        as _:Integer?.Type,
        with decode:(Integer) throws -> T) throws -> T?
        where Integer:FixedWidthInteger
    {
        try self.decode(mapping: key) { try $0.as(Integer?.self).map(decode) } ?? nil
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<Binary, T>(mapping key:String,
        as _:Binary.Type,
        with decode:(Binary) throws -> T) throws -> T?
        where Binary:BinaryFloatingPoint
    {
        try self.decode(mapping: key) { try decode(try $0.as(Binary.self)) }
    }
    @inlinable public
    func decode<Binary, T>(mapping key:String,
        as _:Binary?.Type,
        with decode:(Binary) throws -> T) throws -> T?
        where Binary:BinaryFloatingPoint
    {
        try self.decode(mapping: key) { try $0.as(Binary?.self).map(decode) } ?? nil
    }
}
