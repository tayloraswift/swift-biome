
extension BSON.Value
{
    @inlinable public 
    func `as`(_:Bool.Type) throws -> Bool
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Decimal128.Type) throws -> BSON.Decimal128
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:String.Type) throws -> String
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Regex.Type) throws -> BSON.Regex
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Identifier.Type) throws -> BSON.Identifier
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Millisecond.Type) throws -> BSON.Millisecond
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Tuple<Bytes>.Type) throws -> BSON.Tuple<Bytes>
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Document<Bytes>.Type) throws -> BSON.Document<Bytes>
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`<Integer>(_:Integer.Type) throws -> Integer
        where Integer:FixedWidthInteger
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`<Binary>(_:Binary.Type) throws -> Binary
        where Binary:BinaryFloatingPoint
    {
        try self.match(Self.as(_:))
    }
}
extension BSON.Value
{
    @inlinable public 
    func `as`(_:Bool?.Type) throws -> Bool?
    {
        try self.flatMatch(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Decimal128?.Type) throws -> BSON.Decimal128?
    {
        try self.flatMatch(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:String?.Type) throws -> String?
    {
        try self.flatMatch(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Regex?.Type) throws -> BSON.Regex?
    {
        try self.flatMatch(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Identifier?.Type) throws -> BSON.Identifier?
    {
        try self.flatMatch(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Millisecond?.Type) throws -> BSON.Millisecond?
    {
        try self.flatMatch(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Tuple<Bytes>?.Type) throws -> BSON.Tuple<Bytes>?
    {
        try self.flatMatch(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Document<Bytes>?.Type) throws -> BSON.Document<Bytes>?
    {
        try self.flatMatch(Self.as(_:))
    }
    @inlinable public 
    func `as`<Integer>(_:Integer?.Type) throws -> Integer? 
        where Integer:FixedWidthInteger
    {
        try self.flatMatch(Self.as(_:))
    }
    @inlinable public 
    func `as`<Binary>(_:Binary?.Type) throws -> Binary? 
        where Binary:BinaryFloatingPoint
    {
        try self.flatMatch(Self.as(_:))
    }
    @inlinable public
    func `as`<StringCoded>(cases _:StringCoded?.Type = StringCoded?.self) throws -> StringCoded?
        where StringCoded:RawRepresentable, StringCoded.RawValue == String
    {
        try self.flatMatch(Self.as(cases:))
    }
    @inlinable public
    func `as`<CharacterCoded>(cases _:CharacterCoded?.Type = CharacterCoded?.self) throws -> CharacterCoded?
        where CharacterCoded:RawRepresentable, CharacterCoded.RawValue == Character
    {
        try self.flatMatch(Self.as(cases:))
    }
    @inlinable public
    func `as`<ScalarCoded>(cases _:ScalarCoded?.Type = ScalarCoded?.self) throws -> ScalarCoded?
        where ScalarCoded:RawRepresentable, ScalarCoded.RawValue == Unicode.Scalar
    {
        try self.flatMatch(Self.as(cases:))
    }
    @inlinable public
    func `as`<IntegerCoded>(cases _:IntegerCoded?.Type = IntegerCoded?.self) throws -> IntegerCoded?
        where IntegerCoded:RawRepresentable, IntegerCoded.RawValue:FixedWidthInteger
    {
        try self.flatMatch(Self.as(cases:))
    }
}

extension BSONDecoderField
{
    @inlinable public
    func decode(to _:Bool.Type = Bool.self) throws -> Bool
    {
        try self.decode { try $0.as(Bool.self) }
    }
    @inlinable public
    func decode(to _:BSON.Decimal128.Type = BSON.Decimal128.self) throws -> BSON.Decimal128
    {
        try self.decode { try $0.as(BSON.Decimal128.self) }
    }
    @inlinable public
    func decode(to _:String.Type = String.self) throws -> String
    {
        try self.decode { try $0.as(String.self) }
    }
    @inlinable public
    func decode(to _:BSON.Regex.Type = BSON.Regex.self) throws -> BSON.Regex
    {
        try self.decode { try $0.as(BSON.Regex.self) }
    }
    @inlinable public
    func decode(to _:BSON.Identifier.Type = BSON.Identifier.self) throws -> BSON.Identifier
    {
        try self.decode { try $0.as(BSON.Identifier.self) }
    }
    @inlinable public
    func decode(to _:BSON.Millisecond.Type = BSON.Millisecond.self) throws -> BSON.Millisecond
    {
        try self.decode { try $0.as(BSON.Millisecond.self) }
    }
    @inlinable public
    func decode(to _:BSON.Tuple<Bytes>.Type = BSON.Tuple<Bytes>.self) throws -> BSON.Tuple<Bytes>
    {
        try self.decode { try $0.as(BSON.Tuple<Bytes>.self) }
    }
    @inlinable public
    func decode(to _:BSON.Document<Bytes>.Type = BSON.Document<Bytes>.self) throws -> BSON.Document<Bytes>
    {
        try self.decode { try $0.as(BSON.Document<Bytes>.self) }
    }
    @inlinable public
    func decode<Integer>(to _:Integer.Type = Integer.self) throws -> Integer
        where Integer:FixedWidthInteger
    {
        try self.decode { try $0.as(Integer.self) }
    }
    @inlinable public
    func decode<Binary>(to _:Binary.Type = Binary.self) throws -> Binary
        where Binary:BinaryFloatingPoint
    {
        try self.decode { try $0.as(Binary.self) }
    }
    @inlinable public
    func decode<StringCoded>(cases _:StringCoded.Type = StringCoded.self) throws -> StringCoded
        where StringCoded:RawRepresentable, StringCoded.RawValue == String
    {
        try self.decode { try $0.as(cases: StringCoded.self) }
    }
    @inlinable public
    func decode<CharacterCoded>(cases _:CharacterCoded.Type = CharacterCoded.self) throws -> CharacterCoded
        where CharacterCoded:RawRepresentable, CharacterCoded.RawValue == Character
    {
        try self.decode { try $0.as(cases: CharacterCoded.self) }
    }
    @inlinable public
    func decode<ScalarCoded>(cases _:ScalarCoded.Type = ScalarCoded.self) throws -> ScalarCoded
        where ScalarCoded:RawRepresentable, ScalarCoded.RawValue == Unicode.Scalar
    {
        try self.decode { try $0.as(cases: ScalarCoded.self) }
    }
    @inlinable public
    func decode<IntegerCoded>(cases _:IntegerCoded.Type = IntegerCoded.self) throws -> IntegerCoded
        where IntegerCoded:RawRepresentable, IntegerCoded.RawValue:FixedWidthInteger
    {
        try self.decode { try $0.as(cases: IntegerCoded.self) }
    }
}

extension BSONDecoderField
{
    @inlinable public
    func decode(to _:Bool?.Type = Bool?.self) throws -> Bool?
    {
        try self.decode { try $0.as(Bool?.self) }
    }
    @inlinable public
    func decode(to _:BSON.Decimal128?.Type = BSON.Decimal128?.self) throws -> BSON.Decimal128?
    {
        try self.decode { try $0.as(BSON.Decimal128?.self) }
    }
    @inlinable public
    func decode(to _:String?.Type = String?.self) throws -> String?
    {
        try self.decode { try $0.as(String?.self) }
    }
    @inlinable public
    func decode(to _:BSON.Regex?.Type = BSON.Regex?.self) throws -> BSON.Regex?
    {
        try self.decode { try $0.as(BSON.Regex?.self) }
    }
    @inlinable public
    func decode(to _:BSON.Identifier?.Type = BSON.Identifier?.self) throws -> BSON.Identifier?
    {
        try self.decode { try $0.as(BSON.Identifier?.self) }
    }
    @inlinable public
    func decode(to _:BSON.Millisecond?.Type = BSON.Millisecond?.self) throws -> BSON.Millisecond?
    {
        try self.decode { try $0.as(BSON.Millisecond?.self) }
    }
    @inlinable public
    func decode(to _:BSON.Tuple<Bytes>?.Type = BSON.Tuple<Bytes>?.self) throws -> BSON.Tuple<Bytes>?
    {
        try self.decode { try $0.as(BSON.Tuple<Bytes>?.self) }
    }
    @inlinable public
    func decode(to _:BSON.Document<Bytes>?.Type = BSON.Document<Bytes>?.self) throws -> BSON.Document<Bytes>?
    {
        try self.decode { try $0.as(BSON.Document<Bytes>?.self) }
    }
    @inlinable public
    func decode<Integer>(to _:Integer?.Type = Integer?.self) throws -> Integer?
        where Integer:FixedWidthInteger
    {
        try self.decode { try $0.as(Integer?.self) }
    }
    @inlinable public
    func decode<Binary>(to _:Binary?.Type = Binary?.self) throws -> Binary?
        where Binary:BinaryFloatingPoint
    {
        try self.decode { try $0.as(Binary?.self) }
    }
    @inlinable public
    func decode<StringCoded>(cases _:StringCoded?.Type = StringCoded?.self) throws -> StringCoded?
        where StringCoded:RawRepresentable, StringCoded.RawValue == String
    {
        try self.decode { try $0.as(cases: StringCoded?.self) }
    }
    @inlinable public
    func decode<CharacterCoded>(cases _:CharacterCoded?.Type = CharacterCoded?.self) throws -> CharacterCoded?
        where CharacterCoded:RawRepresentable, CharacterCoded.RawValue == Character
    {
        try self.decode { try $0.as(cases: CharacterCoded?.self) }
    }
    @inlinable public
    func decode<ScalarCoded>(cases _:ScalarCoded?.Type = ScalarCoded?.self) throws -> ScalarCoded?
        where ScalarCoded:RawRepresentable, ScalarCoded.RawValue == Unicode.Scalar
    {
        try self.decode { try $0.as(cases: ScalarCoded?.self) }
    }
    @inlinable public
    func decode<IntegerCoded>(cases _:IntegerCoded?.Type = IntegerCoded?.self) throws -> IntegerCoded?
        where IntegerCoded:RawRepresentable, IntegerCoded.RawValue:FixedWidthInteger
    {
        try self.decode { try $0.as(cases: IntegerCoded?.self) }
    }
}

extension BSONDecoderField
{
    @inlinable public
    func decode<T>(as _:Bool.Type,
        with decode:(Bool) throws -> T) throws -> T
    {
        try self.decode { try decode(try $0.as(Bool.self)) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Decimal128.Type,
        with decode:(BSON.Decimal128) throws -> T) throws -> T
    {
        try self.decode { try decode(try $0.as(BSON.Decimal128.self)) }
    }
    @inlinable public
    func decode<T>(as _:String.Type,
        with decode:(String) throws -> T) throws -> T
    {
        try self.decode { try decode(try $0.as(String.self)) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Regex.Type,
        with decode:(BSON.Regex) throws -> T) throws -> T
    {
        try self.decode { try decode(try $0.as(BSON.Regex.self)) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Identifier.Type,
        with decode:(BSON.Identifier) throws -> T) throws -> T
    {
        try self.decode { try decode(try $0.as(BSON.Identifier.self)) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Millisecond.Type,
        with decode:(BSON.Millisecond) throws -> T) throws -> T
    {
        try self.decode { try decode(try $0.as(BSON.Millisecond.self)) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Tuple<Bytes>.Type,
        with decode:(BSON.Tuple<Bytes>) throws -> T) throws -> T
    {
        try self.decode { try decode(try $0.as(BSON.Tuple<Bytes>.self)) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Array<Bytes.SubSequence>.Type,
        with decode:(BSON.Array<Bytes.SubSequence>) throws -> T) throws -> T
    {
        try self.decode { try decode(try $0.as(BSON.Array<Bytes.SubSequence>.self)) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Document<Bytes>.Type,
        with decode:(BSON.Document<Bytes>) throws -> T) throws -> T
    {
        try self.decode { try decode(try $0.as(BSON.Document<Bytes>.self)) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Dictionary<Bytes.SubSequence>.Type,
        with decode:(BSON.Dictionary<Bytes.SubSequence>) throws -> T) throws -> T
    {
        try self.decode { try decode(try $0.as(BSON.Dictionary<Bytes.SubSequence>.self)) }
    }
    @inlinable public
    func decode<Integer, T>(as _:Integer.Type,
        with decode:(Integer) throws -> T) throws -> T
        where Integer:FixedWidthInteger
    {
        try self.decode { try decode(try $0.as(Integer.self)) }
    }
    @inlinable public
    func decode<Binary, T>(as _:Binary.Type,
        with decode:(Binary) throws -> T) throws -> T
        where Binary:BinaryFloatingPoint
    {
        try self.decode { try decode(try $0.as(Binary.self)) }
    }
}

extension BSONDecoderField
{
    @inlinable public
    func decode<T>(as _:Bool?.Type,
        with decode:(Bool) throws -> T) throws -> T?
    {
        try self.decode { try $0.as(Bool?.self).map(decode) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Decimal128?.Type,
        with decode:(BSON.Decimal128) throws -> T) throws -> T?
    {
        try self.decode { try $0.as(BSON.Decimal128?.self).map(decode) }
    }
    @inlinable public
    func decode<T>(as _:String?.Type,
        with decode:(String) throws -> T) throws -> T?
    {
        try self.decode { try $0.as(String?.self).map(decode) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Regex?.Type,
        with decode:(BSON.Regex) throws -> T) throws -> T?
    {
        try self.decode { try $0.as(BSON.Regex?.self).map(decode) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Identifier?.Type,
        with decode:(BSON.Identifier) throws -> T) throws -> T?
    {
        try self.decode { try $0.as(BSON.Identifier?.self).map(decode) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Millisecond?.Type,
        with decode:(BSON.Millisecond) throws -> T) throws -> T?
    {
        try self.decode { try $0.as(BSON.Millisecond?.self).map(decode) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Tuple<Bytes>?.Type,
        with decode:(BSON.Tuple<Bytes>) throws -> T) throws -> T?
    {
        try self.decode { try $0.as(BSON.Tuple<Bytes>?.self).map(decode) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Array<Bytes.SubSequence>?.Type,
        with decode:(BSON.Array<Bytes.SubSequence>) throws -> T) throws -> T?
    {
        try self.decode { try $0.as(BSON.Array<Bytes.SubSequence>?.self).map(decode) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Document<Bytes>?.Type,
        with decode:(BSON.Document<Bytes>) throws -> T) throws -> T?
    {
        try self.decode { try $0.as(BSON.Document<Bytes>?.self).map(decode) }
    }
    @inlinable public
    func decode<T>(as _:BSON.Dictionary<Bytes.SubSequence>?.Type,
        with decode:(BSON.Dictionary<Bytes.SubSequence>) throws -> T) throws -> T?
    {
        try self.decode { try $0.as(BSON.Dictionary<Bytes.SubSequence>?.self).map(decode) }
    }
    @inlinable public
    func decode<Integer, T>(as _:Integer?.Type,
        with decode:(Integer) throws -> T) throws -> T?
        where Integer:FixedWidthInteger
    {
        try self.decode { try $0.as(Integer?.self).map(decode) }
    }
    @inlinable public
    func decode<Binary, T>(as _:Binary?.Type,
        with decode:(Binary) throws -> T) throws -> T?
        where Binary:BinaryFloatingPoint
    {
        try self.decode { try $0.as(Binary?.self).map(decode) }
    }
}
