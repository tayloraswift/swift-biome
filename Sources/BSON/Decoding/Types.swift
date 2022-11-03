extension BSON.Variant
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
    /// - returns: [`()`]() if this variant is ``null``, [`nil`]() otherwise.
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
    /// - Returns: The payload of this variant if it matches ``bool(_:)``, 
    ///     [`nil`]() otherwise.
    @inlinable public 
    func `as`(_:Bool.Type) -> Bool?
    {
        switch self 
        {
        case .bool(let value):  return value
        default:                return nil 
        }
    }
    /// Attempts to load an instance of some ``FixedWidthInteger`` from this variant.
    /// 
    /// - Returns: An integer derived from the payload of this variant
    ///     if it matches one of ``int32(_:)``, ``int64(_:)``, or ``uint64(_:)``, 
    ///     and it can be represented exactly by [`T`](); [`nil`]() otherwise.
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
                throw BSON.IntegerOverflowError.int32(int32, overflows: Integer.self)
            }
        case .int64(let int64):
            if let integer:Integer = .init(exactly: int64)
            {
                return integer
            }
            else
            {
                throw BSON.IntegerOverflowError.int64(int64, overflows: Integer.self)
            }
        case .uint64(let uint64):
            if let integer:Integer = .init(exactly: uint64)
            {
                return integer
            }
            else
            {
                throw BSON.IntegerOverflowError.uint64(uint64, overflows: Integer.self)
            }
        default:
            return nil
        }
    }
    /// Attempts to load an instance of some ``BinaryFloatingPoint`` type from this variant.
    /// 
    /// - Returns: The closest value of [`T`]() to the payload of this 
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
    /// Attempts to unwrap an instance of ``String`` from this variant. Its UTF-8 code
    /// units will be validated (and repaired if needed).
    /// 
    /// - Returns: The payload of this variant, decoded to a ``String``, if it matches
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
    /// Attempts to unwrap and parse an array from this variant.
    /// 
    /// This method will only attempt to parse statically-typed BSON tuples; it will not
    /// inspect general documents to determine if they are valid tuples.
    /// 
    /// - Returns: The payload of this variant, parsed to an array, if it matches
    ///     ``tuple(_:)`` and could be successfully parsed, [`nil`]() otherwise.
    ///
    /// >   Complexity: 
    //      O(*n*), where *n* is the number of elements in the source tuple.
    @inlinable public 
    func `as`(_:[BSON.Variant<Bytes.SubSequence>].Type) -> [BSON.Variant<Bytes.SubSequence>]?
    {
        switch self 
        {
        case .tuple(let tuple): return try? tuple.parse()
        default:                return nil
        }
    }
    
    /// Attempts to unwrap an array of key-value pairs from this variant.
    /// 
    /// - Returns: The payload of this variant if it matches ``document(_:)``
    ///     or ``tuple(_:)``, [`nil`]() otherwise.
    /// 
    /// The order of the items reflects the order in which they appear in the 
    /// source document. If the source document was a tuple, the string keys
    /// will contain the tuple indices encoded as base-10 strings (without leading zeros).
    /// 
    /// >   Complexity: 
    ///     O(*n*), where *n* is the number of fields in the source document.
    @inlinable public 
    func `as`(_:[(key:String, value:BSON.Variant<Bytes.SubSequence>)].Type)
        -> [(key:String, value:BSON.Variant<Bytes.SubSequence>)]? 
    {
        switch self 
        {
        case .document(let document):
            return try? document.parse()
        case .tuple(let tuple):
            return try? tuple.document.parse()
        default:
            return nil 
        }
    }
    /// Attempts to load a dictionary from this variant, de-duplicating keys 
    /// with the given closure.
    /// 
    /// - Returns: A dictionary derived from the payload of this variant if it 
    ///     matches ``document(_:)`` or ``tuple(_:)``, [`nil`]() otherwise.
    /// 
    /// Fields can occur more than once in the same document. (Although such documents
    /// are considered degenerate BSON). To handle this, an API consumer might 
    /// elect to keep only the last occurrence of a particular key.
    ///
    /// ```swift 
    /// let dictionary:[String: BSON.Variant<Bytes.SubSequence>]? =
    ///     bson.as([String: BSON.Variant<Bytes.SubSequence>].self) { $1 }
    /// ```
    ///
    /// Key duplication can interact with unicode normalization in unexpected 
    /// ways. Because BSON is defined in UTF-8, other BSON encoders may not align 
    /// with the behavior of ``String.==(_:_:)``, since that operator 
    /// compares grapheme clusters and not UTF-8 code units. 
    /// 
    /// For example, if a document vends separate keys for [`"\u{E9}"`]() ([`"é"`]()) and 
    /// [`"\u{65}\u{301}"`]() (also [`"é"`](), perhaps, because the document is 
    /// being used to bootstrap a unicode table), uniquing them by ``String`` 
    /// comparison will drop one of the values.
    ///
    /// Calling this method is equivalent to calling ``as(_:)``, and chaining its 
    /// optional result through ``Dictionary.init(_:uniquingKeysWith:)``. See the 
    /// documentation for ``as(_:)`` for more details about the behavior of this method.
    /// 
    /// >   Complexity: 
    ///     O(*n*), where *n* is the number of fields in the source object.
    ///
    /// >   Warning: 
    ///     When you convert an object to a dictionary representation, you lose the ordering 
    ///     information for the object items. Reencoding it may produce a BSON 
    ///     document that contains the same data, but does not compare equal.
    @inlinable public 
    func `as`(_:[String: BSON.Variant<Bytes.SubSequence>].Type, 
        uniquingKeysWith combine:
        (
            BSON.Variant<Bytes.SubSequence>,
            BSON.Variant<Bytes.SubSequence>
        ) throws -> BSON.Variant<Bytes.SubSequence>)
        rethrows -> [String: BSON.Variant<Bytes.SubSequence>]? 
    {
        try self.as([(key:String, value:BSON.Variant<Bytes.SubSequence>)].self).map
        {
            try [String: BSON.Variant<Bytes.SubSequence>].init($0, uniquingKeysWith: combine)
        }
    }
}
