import TraceableErrors

extension BSON
{
    /// A decoder failed to cast a variant to an expected type.
    @frozen public 
    struct PrimitiveError<T>:Equatable, Error
    {
        public
        let variant:BSON

        @inlinable public
        init(variant:BSON)
        {
            self.variant = variant
        }
    }
}
extension BSON.PrimitiveError:TraceableErrorRoot
{
    /// Returns the string [`"primitive error"`]().
    public static 
    var namespace:String 
    {
        "primitive error"
    }
    public
    var message:String 
    {
        "cannot cast variant of type '\(self.variant)' to type '\(T.self)'"
    }
}

extension BSON
{
    /// An overflow occurred while converting an integer value to a desired type.
    @frozen public
    enum IntegerOverflowError<Overflowed>:Equatable, Error where Overflowed:FixedWidthInteger
    {
        case int32(Int32)
        case int64(Int64)
        case uint64(UInt64)
    }
}
extension BSON.IntegerOverflowError:TraceableErrorRoot
{
    /// Returns the string [`"integer overflow error"`]().
    public static 
    var namespace:String 
    {
        "integer overflow error"
    }
    
    public
    var message:String 
    {
        switch self
        {
        case .int32 (let value):
            return "value '\(value)' of type 'int32' overflows decoded type '\(Overflowed.self)'"
        case .int64 (let value):
            return "value '\(value)' of type 'int64' overflows decoded type '\(Overflowed.self)'"
        case .uint64(let value):
            return "value '\(value)' of type 'uint64' overflows decoded type '\(Overflowed.self)'"
        }
    }
}


extension BSON.Value
{
    /// Promotes a [`nil`]() result to a thrown ``PrimitiveError``.
    /// 
    /// >   Throws: A ``PrimitiveError`` if the given curried method returns [`nil`]().
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
            throw BSON.PrimitiveError<T>.init(variant: self.type)
        }
    }
    /// Promotes a [`nil`]() result to a thrown ``PrimitiveError``, if this variant 
    /// is not an explicit ``null``.
    /// 
    /// `flatMatch(_:)` is to ``match(_:)`` what ``Optional.flatMap(_:)`` is to 
    /// ``Optional.map(_:)``.
    /// 
    /// -   Returns: [`nil`]() if this variant is an explicit ``null``; the result of 
    ///     applying the given curried method otherwise.
    /// 
    /// >   Throws: A ``PrimitiveError`` if the given curried method returns [`nil`]().
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
            throw BSON.PrimitiveError<T?>.init(variant: self.type)
        }
    }
}
extension BSON.Value
{
    /// Indicates if this variant is ``null``.
    @inlinable public 
    func `is`(_:Void.Type) -> Bool
    {
        switch self 
        {
        case .null: return true 
        default:    return false
        }
    }
    /// Attempts to unwrap an explicit ``null`` from this variant.
    /// 
    /// -   Returns:
    ///     [`()`]() if this variant is ``null``, [`nil`]() otherwise.
    @inlinable public 
    func `as`(_:Void.Type) -> Void?
    {
        switch self 
        {
        case .null: return ()
        default:    return nil 
        }
    }
    /// Attempts to unwrap an instance of ``Bool`` from this variant.
    /// 
    /// -   Returns:
    ///     The payload of this variant if it matches ``bool(_:)``, 
    ///     [`nil`]() otherwise.
    @inlinable public 
    func `as`(_:Bool.Type) -> Bool?
    {
        switch self 
        {
        case .bool(let bool):   return bool
        default:                return nil 
        }
    }
    /// Attempts to load an instance of some ``FixedWidthInteger`` from this variant.
    /// 
    /// -   Returns:
    ///     An integer derived from the payload of this variant
    ///     if it matches one of ``int32(_:)``, ``int64(_:)``, or ``uint64(_:)``, 
    ///     and it can be represented exactly by [`T`](); [`nil`]() otherwise.
    ///
    /// The ``decimal128(_:)``, ``double(_:)``, and ``millisecond(_:)`` variants will
    /// *not* match.
    ///
    /// This method reports failure in two ways — it returns [`nil`]() on a type 
    /// mismatch, and it [`throws`]() a ``BSON/IntegerOverflowError`` if this variant 
    /// was an integer, but it could not be represented exactly by [`T`]().
    @inlinable public 
    func `as`<Integer>(_:Integer.Type) throws -> Integer? 
        where Integer:FixedWidthInteger
    {
        switch self
        {
        case .int32(let int32):
            if let integer:Integer = .init(exactly: int32)
            {
                return integer
            }
            else
            {
                throw BSON.IntegerOverflowError<Integer>.int32(int32)
            }
        case .int64(let int64):
            if let integer:Integer = .init(exactly: int64)
            {
                return integer
            }
            else
            {
                throw BSON.IntegerOverflowError<Integer>.int64(int64)
            }
        case .uint64(let uint64):
            if let integer:Integer = .init(exactly: uint64)
            {
                return integer
            }
            else
            {
                throw BSON.IntegerOverflowError<Integer>.uint64(uint64)
            }
        default:
            return nil
        }
    }
    /// Attempts to load an instance of some ``BinaryFloatingPoint`` type from this variant.
    /// 
    /// -   Returns:
    ///     The closest value of [`T`]() to the payload of this 
    ///     variant if it matches ``double(_:)``, [`nil`]() otherwise.
    @inlinable public 
    func `as`<Binary>(_:Binary.Type) -> Binary?
        where Binary:BinaryFloatingPoint
    {
        switch self 
        {
        case .double(let double):   return .init(double)
        default:                    return nil 
        }
    }
    /// Attempts to unwrap an instance of ``Decimal128`` from this variant.
    /// 
    /// -   Returns:
    ///     The payload of this variant if it matches ``decimal128(_:)``, 
    ///     [`nil`]() otherwise.
    @inlinable public 
    func `as`(_:BSON.Decimal128.Type) -> BSON.Decimal128?
    {
        switch self 
        {
        case .decimal128(let decimal):  return decimal
        default:                        return nil 
        }
    }
    /// Attempts to unwrap an instance of ``String`` from this variant. Its UTF-8 code
    /// units will be validated (and repaired if needed).
    /// 
    /// -   Returns:
    ///     The payload of this variant, decoded to a ``String``, if it matches
    ///     ``string(_:)``, [`nil`]() otherwise.
    ///
    /// >   Complexity: 
    ///     O(*n*), where *n* is the length of the string.
    @inlinable public 
    func `as`(_:String.Type) -> String?
    {
        switch self 
        {
        case .string(let string):   return string.description
        default:                    return nil
        }
    }
    /// Attempts to unwrap an instance of ``Regex`` from this variant.
    /// 
    /// -   Returns:
    ///     The payload of this variant if it matches ``regex(_:)``,
    ///     [`nil`]() otherwise.
    @inlinable public 
    func `as`(_:BSON.Regex.Type) -> BSON.Regex?
    {
        switch self 
        {
        case .regex(let regex):
            return regex
        default:
            return nil 
        }
    }
    /// Attempts to unwrap a tuple from this variant.
    /// 
    /// -   Returns:
    ///     The payload of this variant if it matches ``tuple(_:)``,
    ///     [`nil`]() otherwise.
    ///
    /// >   Complexity: O(1).
    @inlinable public 
    func `as`(_:BSON.Tuple<Bytes>.Type) -> BSON.Tuple<Bytes>?
    {
        switch self 
        {
        case .tuple(let tuple): return tuple
        default:                return nil
        }
    }
    /// Attempts to unwrap a document from this variant.
    /// 
    /// -   Returns: The payload of this variant if it matches ``document(_:)``
    ///     or ``tuple(_:)``, [`nil`]() otherwise.
    /// 
    /// If the variant was a tuple, the string keys of the returned document are likely
    /// (but not guaranteed) to be the tuple indices encoded as base-10 strings, without
    /// leading zeros.
    /// 
    /// >   Complexity: O(1).
    @inlinable public 
    func `as`(_:BSON.Document<Bytes>.Type) -> BSON.Document<Bytes>?
    {
        switch self 
        {
        case .document(let document):
            return document
        case .tuple(let tuple):
            return tuple.document
        default:
            return nil 
        }
    }
    /// Attempts to unwrap an instance of ``Identifier`` from this variant.
    /// 
    /// -   Returns:
    ///     The payload of this variant if it matches ``id(_:)`` or ``pointer(_:_:)``,
    ///     [`nil`]() otherwise.
    @inlinable public 
    func `as`(_:BSON.Identifier.Type) -> BSON.Identifier?
    {
        switch self 
        {
        case .id(let id):
            return id
        case .pointer(_, let id):
            return id
        default:
            return nil 
        }
    }
    /// Attempts to unwrap an instance of ``Millisecond`` from this variant.
    /// 
    /// -   Returns:
    ///     The payload of this variant if it matches ``millisecond(_:)``,
    ///     [`nil`]() otherwise.
    @inlinable public 
    func `as`(_:BSON.Millisecond.Type) -> BSON.Millisecond?
    {
        switch self 
        {
        case .millisecond(let millisecond):
            return millisecond
        default:
            return nil 
        }
    }
}

extension BSON.Value
{
    /// Attempts to unwrap and parse an array-decoder from this variant.
    ///
    /// This method will only attempt to parse statically-typed BSON tuples; it will not
    /// inspect general documents to determine if they are valid tuples.
    /// 
    /// -   Returns:
    ///     The payload of this variant, parsed to an array-decoder, if it matches
    ///     ``tuple(_:)`` and could be successfully parsed, [`nil`]() otherwise.
    ///
    /// To get a plain array with no decoding interface, cast this variant to
    /// a ``BSON/Tuple`` and call its ``BSON/Tuple/.parse()`` method. Alternatively,
    /// you can use this method and access the ``BSON//Array.elements`` property.
    ///
    /// >   Complexity: 
    //      O(*n*), where *n* is the number of elements in the source tuple.
    @inlinable public 
    func `as`(_:BSON.Array<Bytes.SubSequence>.Type) throws -> BSON.Array<Bytes.SubSequence>
    {
        .init(try self.as(BSON.Tuple<Bytes>.self).parse())
    }
    /// Attempts to unwrap and parse an array-decoder from this variant, returning
    /// [`nil`]() instead of throwing an error if this variant is an explicit ``null``.
    @inlinable public 
    func `as`(_:BSON.Array<Bytes.SubSequence>?.Type) throws -> BSON.Array<Bytes.SubSequence>?
    {
        (try self.as(BSON.Tuple<Bytes>?.self)?.parse())
            .map(BSON.Array<Bytes.SubSequence>.init(_:))
    }

    /// Attempts to unwrap and parse a fixed-length array-decoder from this variant.
    /// 
    /// -   Returns:
    ///     The payload of this variant, parsed to an array-decoder, if it matches
    ///     ``tuple(_:)``, could be successfully parsed, and contains the expected
    ///     number of elements.
    ///
    /// >   Throws:
    ///     An ``ArrayShapeError`` if an array was successfully unwrapped and 
    ///     parsed, but it did not contain the expected number of elements.
    @inlinable public 
    func `as`(_:BSON.Array<Bytes.SubSequence>.Type,
        count:Int) throws -> BSON.Array<Bytes.SubSequence>
    {
        let aggregate:[BSON.Value<Bytes.SubSequence>] =
            try self.as(BSON.Tuple<Bytes>.self).parse()
        if  aggregate.count == count 
        {
            return .init(aggregate)
        }
        else 
        {
            throw BSON.ArrayShapeError.init(count: aggregate.count, expected: count)
        }
    }
    /// Attempts to unwrap and parse a fixed-length array-decoder from this variant,
    /// returning [`nil`]() instead of throwing an error if this variant is an explicit
    /// ``null``.
    @inlinable public 
    func `as`(_:BSON.Array<Bytes.SubSequence>?.Type,
        count:Int) throws -> BSON.Array<Bytes.SubSequence>?
    {
        guard   let aggregate:[BSON.Value<Bytes.SubSequence>] =
                    try self.as(BSON.Tuple<Bytes>?.self)?.parse()
        else
        {
            return nil
        }
        if  aggregate.count == count 
        {
            return .init(aggregate)
        }
        else 
        {
            throw BSON.ArrayShapeError.init(count: aggregate.count, expected: count)
        }
    }

    /// Attempts to unwrap and parse an array-decoder from this variant, whose length 
    /// satifies the given criteria.
    /// 
    /// -   Returns:
    ///     The payload of this variant if it matches ``tuple(_:)``, could be
    ///     successfully parsed, and contains the expected number of elements.
    ///
    /// >   Throws:
    ///     An ``ArrayShapeError`` if an array was successfully unwrapped and 
    ///     parsed, but it did not contain the expected number of elements.
    @inlinable public 
    func `as`(_:BSON.Array<Bytes.SubSequence>.Type, 
        where predicate:(_ count:Int) throws -> Bool) throws -> BSON.Array<Bytes.SubSequence>
    {
        let aggregate:[BSON.Value<Bytes.SubSequence>] =
            try self.as(BSON.Tuple<Bytes>.self).parse()
        if try predicate(aggregate.count)
        {
            return .init(aggregate)
        }
        else 
        {
            throw BSON.ArrayShapeError.init(count: aggregate.count)
        }
    }
    /// Attempts to unwrap and parse an array-decoder from this variant, whose length 
    /// satifies the given criteria.
    /// Returns [`nil`]() instead of throwing an error if this variant is an explicit
    /// ``null``.
    @inlinable public 
    func `as`(_:BSON.Array<Bytes.SubSequence>?.Type, 
        where predicate:(_ count:Int) throws -> Bool) throws -> BSON.Array<Bytes.SubSequence>?
    {
        guard   let aggregate:[BSON.Value<Bytes.SubSequence>] =
                    try self.as(BSON.Tuple<Bytes>?.self)?.parse()
        else
        {
            return nil
        }
        if try predicate(aggregate.count)
        {
            return .init(aggregate)
        }
        else 
        {
            throw BSON.ArrayShapeError.init(count: aggregate.count)
        }
    }
}
extension BSON.Value
{
    /// Attempts to load a dictionary-decoder from this variant.
    /// 
    /// - Returns: A dictionary-decoder derived from the payload of this variant if it 
    ///     matches ``document(_:)`` or ``tuple(_:)``, [`nil`]() otherwise.
    ///
    /// This method will throw a ``BSON//DictionaryKeyError`` more than one document
    /// field contains a key with the same name.
    ///
    /// Key duplication can interact with unicode normalization in unexpected 
    /// ways. Because BSON is defined in UTF-8, other BSON encoders may not align 
    /// with the behavior of ``String.==(_:_:)``, since that operator 
    /// compares grapheme clusters and not UTF-8 code units. 
    /// 
    /// For example, if a document vends separate keys for [`"\u{E9}"`]() ([`"é"`]()) and 
    /// [`"\u{65}\u{301}"`]() (also [`"é"`](), perhaps, because the document is 
    /// being used to bootstrap a unicode table), uniquing them by ``String`` 
    /// comparison would drop one of the values.
    ///
    /// To get a plain array of key-value pairs with no decoding interface, cast this
    /// variant to a ``BSON/Document`` and call its ``BSON/Document/.parse()`` method.
    /// 
    /// >   Complexity: 
    ///     O(*n*), where *n* is the number of fields in the source document.
    ///
    /// >   Warning: 
    ///     When you convert an object to a dictionary representation, you lose the ordering 
    ///     information for the object items. Reencoding it may produce a BSON 
    ///     document that contains the same data, but does not compare equal.
    @inlinable public 
    func `as`(_:BSON.Dictionary<Bytes.SubSequence>.Type)
        throws -> BSON.Dictionary<Bytes.SubSequence>
    {
        try .init(fields: try self.as(BSON.Document<Bytes>.self).parse())
    }
    /// Attempts to load a dictionary-decoder from this variant,
    /// returning [`nil`]() instead of throwing an error if this variant is an
    /// explicit ``null``.
    @inlinable public 
    func `as`(_:BSON.Dictionary<Bytes.SubSequence>?.Type)
        throws -> BSON.Dictionary<Bytes.SubSequence>?
    {
        try (try self.as(BSON.Document<Bytes>?.self)?.parse())
            .map(BSON.Dictionary<Bytes.SubSequence>.init(fields:))
    }
}

extension BSON.Value
{
    /// Attempts to unwrap an explicit ``null`` from this variant.
    /// 
    /// This method is a throwing variation of ``as(_:)``.
    @inlinable public 
    func `as`(_:Void.Type) throws 
    {
        try self.match(Self.as(_:)) as Void
    }
}
extension BSONDecoderField
{
    @inlinable public
    func decode(to _:Void.Type = Void.self) throws
    {
        try self.decode { try $0.as(Void.self) }
    }
}

// ``RawRepresentable`` helpers
extension BSON.Value
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
            throw BSON.PrimitiveError<StringCoded>.init(variant: self.type)
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
            throw BSON.PrimitiveError<CharacterCoded>.init(variant: self.type)
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
            throw BSON.PrimitiveError<ScalarCoded>.init(variant: self.type)
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
            throw BSON.PrimitiveError<IntegerCoded>.init(variant: self.type)
        }
    }
}
