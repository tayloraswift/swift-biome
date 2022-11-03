extension BSON.Variant
{
    /// A primitive decoding operation failed.
    public 
    enum PrimitiveError:Error
    {
        /// A decoder successfully unwrapped and parsed an array, but it had the wrong
        /// number of elements.
        case shaping(aggregate:[BSON.Variant<Bytes>], count:Int? = nil)
        /// A decoder failed to unwrap (or parse, if applicable) the expected type from a
        /// variant.
        case matching(variant:BSON.Variant<Bytes>, as:Any.Type)
    }
}
extension BSON.Variant.PrimitiveError
{
    /// Returns the string [`"primitive decoding error"`]().
    public static 
    var namespace:String 
    {
        "primitive decoding error"
    }
    public 
    var message:String 
    {
        switch self 
        {
        case .shaping(aggregate: let aggregate, count: let count?):
            return "could not unwrap aggregate from variant array '\(aggregate)' (expected \(count) elements)"
        case .shaping(aggregate: let aggregate, count: nil):
            return "could not unwrap aggregate from variant array '\(aggregate)'"
        case .matching(variant: let json, as: let type):
            return "could not unwrap type '\(type)' from variant '\(json)'"
        }
    }
}

// ``RawRepresentable`` helpers
extension BSON.Variant
{
    /// Attempts to load an instance of some ``String``-backed type from this variant.
    @inlinable public
    func `as`<StringCoded>(cases _:StringCoded.Type) throws -> StringCoded 
        where StringCoded:RawRepresentable, StringCoded.RawValue == String
    {
        if let value:StringCoded = StringCoded.init(rawValue: try self.as(String.self))
        {
            return value
        }
        else 
        {
            throw PrimitiveError.matching(variant: self, as: StringCoded.self)
        }
    }
    /// Attempts to load an instance of some ``Character``-backed type from this variant.
    @inlinable public
    func `as`<CharacterCoded>(cases _:CharacterCoded.Type) throws -> CharacterCoded 
        where CharacterCoded:RawRepresentable, CharacterCoded.RawValue == Character
    {
        let string:String = try self.as(String.self)

        if  let character:Character = string.first, string.dropFirst().isEmpty,
            let value:CharacterCoded = CharacterCoded.init(rawValue: character)
        {
            return value
        }
        else 
        {
            throw PrimitiveError.matching(variant: self, as: CharacterCoded.self)
        }
    }
    /// Attempts to load an instance of some ``Unicode/Scalar``-backed type from this variant.
    @inlinable public
    func `as`<ScalarCoded>(cases _:ScalarCoded.Type) throws -> ScalarCoded 
        where ScalarCoded:RawRepresentable, ScalarCoded.RawValue == Unicode.Scalar
    {
        let scalars:String.UnicodeScalarView = try self.as(String.self).unicodeScalars

        if  let scalar:Unicode.Scalar = scalars.first, scalars.dropFirst().isEmpty,
            let value:ScalarCoded = ScalarCoded.init(rawValue: scalar)
        {
            return value
        }
        else 
        {
            throw PrimitiveError.matching(variant: self, as: ScalarCoded.self)
        }
    }
    /// Attempts to load an instance of some ``FixedWidthInteger``-backed type from this variant.
    @inlinable public
    func `as`<IntegerCoded>(cases _:IntegerCoded.Type) throws -> IntegerCoded 
        where   IntegerCoded:RawRepresentable, 
                IntegerCoded.RawValue:FixedWidthInteger
    {
        if  let value:IntegerCoded = IntegerCoded.init(
                rawValue: try self.as(IntegerCoded.RawValue.self))
        {
            return value
        }
        else 
        {
            throw PrimitiveError.matching(variant: self, as: IntegerCoded.self)
        }
    }
}

// primitive decoding hooks (throws, does not include null)
extension BSON.Variant
{
    /// Promotes a [`nil`]() result to a thrown ``PrimitiveError``.
    /// 
    /// >   Throws: A ``PrimitiveError.matching(variant:as:)`` if the given 
    ///     curried method returns [`nil`]().
    @inline(__always)
    @inlinable public 
    func match<T>(_ pattern:(Self) -> (T.Type) throws -> T?) throws -> T
    {
        if let value:T = try pattern(self)(T.self)
        {
            return value 
        }
        else 
        {
            throw PrimitiveError.matching(variant: self, as: T.self)
        }
    }
    /// Attempts to unwrap an explicit ``null`` from this variant.
    /// 
    /// This method is a throwing variation of ``as(_:)``.
    @inlinable public 
    func `as`(_:Void.Type) throws 
    {
        try self.match(Self.as(_:)) as Void
    }
    
    /// Attempts to unwrap and parse a fixed-length array from this variant.
    /// 
    /// - Returns: The payload of this variant if it matches ``tuple(_:)``, could be
    ///     successfully parsed, and contains the expected number of elements.
    ///
    /// >   Throws: A ``PrimitiveError.shaping(aggregate:count:)`` if an array was 
    ///     successfully unwrapped and parsed, but it did not contain the expected number
    ///     of elements. The generic parameter of the error is `Bytes.SubSequence`,
    ///     *not* `Bytes`.
    @inlinable public 
    func `as`(_:[BSON.Variant<Bytes.SubSequence>].Type,
        count:Int) throws -> [BSON.Variant<Bytes.SubSequence>]
    {
        let aggregate:[BSON.Variant<Bytes.SubSequence>] = try self.match(Self.as(_:))
        if  aggregate.count == count 
        {
            return aggregate
        }
        else 
        {
            throw BSON.Variant<Bytes.SubSequence>.PrimitiveError.shaping(aggregate: aggregate,
                count: count)
        }
    }
    /// Attempts to unwrap and parse an array from this variant, whose length 
    /// satifies the given criteria.
    /// 
    /// - Returns: The payload of this variant if it matches ``tuple(_:)``, could be
    ///     successfully parsed, and contains the expected number of elements.
    ///
    /// >   Throws: A ``PrimitiveError.shaping(aggregate:count:)`` if an array was 
    ///     successfully unwrapped and parsed, but it did not contain the expected number
    ///     of elements. The generic parameter of the error is `Bytes.SubSequence`,
    ///     *not* `Bytes`.
    @inlinable public 
    func `as`(_:[BSON.Variant<Bytes.SubSequence>].Type,
        where predicate:(_ count:Int) throws -> Bool) throws -> [BSON.Variant<Bytes.SubSequence>]
    {
        let aggregate:[BSON.Variant<Bytes.SubSequence>] = try self.match(Self.as(_:))
        if try predicate(aggregate.count)
        {
            return aggregate
        }
        else 
        {
            throw BSON.Variant<Bytes.SubSequence>.PrimitiveError.shaping(aggregate: aggregate)
        }
    }
    /// Attempts to load a dictionary from this variant, de-duplicating keys 
    /// with the given closure.
    /// 
    /// This method is a throwing variation of 
    /// ``as(_:uniquingKeysWith:)``.
    @inlinable public 
    func `as`(_:[String: BSON.Variant<Bytes.SubSequence>].Type, 
        uniquingKeysWith combine:
        (
            BSON.Variant<Bytes.SubSequence>,
            BSON.Variant<Bytes.SubSequence>
        ) throws -> BSON.Variant<Bytes.SubSequence>)
        throws -> [String: BSON.Variant<Bytes.SubSequence>]
    {
        try [String: BSON.Variant<Bytes.SubSequence>].init(
            try self.as([(key:String, value:BSON.Variant<Bytes.SubSequence>)].self), 
            uniquingKeysWith: combine)
    }
}

// primitive decoding hooks (throws, includes null)
extension BSON.Variant
{
    /// Promotes a [`nil`]() result to a thrown ``PrimitiveError``, if this variant 
    /// is not an explicit ``null``.
    /// 
    /// `flatMatch(_:)` is to ``match(_:)`` what ``Optional.flatMap(_:)`` is to 
    /// ``Optional.map(_:)``.
    /// 
    /// -   Returns: [`nil`]() if this variant is an explicit ``null``; the result of 
    ///     applying the given curried method otherwise.
    /// 
    /// >   Throws: A ``PrimitiveError.matching(variant:as:)`` if the given 
    ///     curried method returns [`nil`]().
    @inline(__always)
    @inlinable public 
    func flatMatch<T>(_ pattern:(Self) -> (T.Type) throws -> T?) throws -> T?
    {
        if case .null = self 
        {
            return nil 
        }
        else if let value:T = try pattern(self)(T.self)
        {
            return value 
        }
        else 
        {
            throw PrimitiveError.matching(variant: self, as: T?.self)
        }
    }
    /// Attempts to unwrap and parse a fixed-length array or an explicit ``null`` 
    /// from this variant.
    /// 
    /// This method is an optionalized variation of 
    /// ``as(_:count:)``.
    @inlinable public 
    func `as`(_:[BSON.Variant<Bytes.SubSequence>]?.Type,
        count:Int) throws -> [BSON.Variant<Bytes.SubSequence>]?
    {
        guard let aggregate:[BSON.Variant<Bytes.SubSequence>] = try self.flatMatch(Self.as(_:))
        else 
        {
            return nil
        }
        if  aggregate.count == count 
        {
            return aggregate
        }
        else 
        {
            throw BSON.Variant<Bytes.SubSequence>.PrimitiveError.shaping(aggregate: aggregate,
                count: count)
        }
    }
    /// Attempts to unwrap and parse an array from this variant, whose length 
    /// satifies the given criteria, or an explicit ``null``.
    /// 
    /// This method is an optionalized variation of 
    /// ``as(_:where:)``.
    @inlinable public 
    func `as`(_:[BSON.Variant<Bytes.SubSequence>]?.Type,
        where predicate:(_ count:Int) throws -> Bool) throws -> [BSON.Variant<Bytes.SubSequence>]?
    {
        guard let aggregate:[BSON.Variant<Bytes.SubSequence>] = try self.flatMatch(Self.as(_:))
        else 
        {
            return nil
        }
        if try predicate(aggregate.count)
        {
            return aggregate
        }
        else 
        {
            throw BSON.Variant<Bytes.SubSequence>.PrimitiveError.shaping(aggregate: aggregate)
        }
    }
    /// Attempts to load a dictionary from this variant, de-duplicating keys 
    /// with the given closure.
    /// 
    /// This method is an optionalized variation of 
    /// ``as(_:uniquingKeysWith:)``.
    @inlinable public 
    func `as`(_:[String: BSON.Variant<Bytes.SubSequence>]?.Type, 
        uniquingKeysWith combine:
        (
            BSON.Variant<Bytes.SubSequence>,
            BSON.Variant<Bytes.SubSequence>
        ) throws -> BSON.Variant<Bytes.SubSequence>)
        throws -> [String: BSON.Variant<Bytes.SubSequence>]? 
    {
        try self.as([(key:String, value:BSON.Variant<Bytes.SubSequence>)]?.self).map 
        {
            try [String: BSON.Variant<Bytes.SubSequence>].init($0, uniquingKeysWith: combine)
        }
    }
} 

extension BSON.Variant 
{
    @inlinable public 
    func `as`(_:Bool.Type) throws -> Bool
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:Bool?.Type) throws -> Bool?
    {
        try self.flatMatch(Self.as(_:))
    }
}

extension BSON.Variant 
{
    @inlinable public 
    func `as`(_:String.Type) throws -> String
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:String?.Type) throws -> String?
    {
        try self.flatMatch(Self.as(_:))
    }
}

extension BSON.Variant 
{
    @inlinable public 
    func `as`(_:[BSON.Variant<Bytes.SubSequence>].Type) throws -> [BSON.Variant<Bytes.SubSequence>]
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:[BSON.Variant<Bytes.SubSequence>]?.Type) throws -> [BSON.Variant<Bytes.SubSequence>]?
    {
        try self.flatMatch(Self.as(_:))
    }
}

extension BSON.Variant 
{
    @inlinable public 
    func `as`(_:[(key:String, value:BSON.Variant<Bytes.SubSequence>)].Type) throws -> [(key:String, value:BSON.Variant<Bytes.SubSequence>)]
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:[(key:String, value:BSON.Variant<Bytes.SubSequence>)]?.Type) throws -> [(key:String, value:BSON.Variant<Bytes.SubSequence>)]?
    {
        try self.flatMatch(Self.as(_:))
    }
}

extension BSON.Variant 
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

extension BSON.Variant 
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