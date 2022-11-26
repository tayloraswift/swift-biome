extension BSON
{
    /// A BSON variant value.
    @frozen public
    enum Value<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        /// A general embedded document.
        case document(Document<Bytes>)
        /// An embedded tuple-document.
        case tuple(Tuple<Bytes>)
        /// A binary array.
        case binary(Binary<Bytes>)
        /// A boolean.
        case bool(Bool)
        /// An [IEEE 754-2008 128-bit decimal](https://en.wikipedia.org/wiki/Decimal128_floating-point_format).
        case decimal128(Decimal128)
        /// A double-precision float.
        case double(Double)
        /// A MongoDB object reference.
        case id(Identifier)
        /// A 32-bit signed integer.
        case int32(Int32)
        /// A 64-bit signed integer.
        case int64(Int64)
        /// Javascript code.
        /// The payload is a library type to permit efficient document traversal.
        case javascript(UTF8<Bytes>)
        /// A javascript scope containing code. This variant is maintained for 
        /// backward-compatibility with older versions of BSON and 
        /// should not be generated. (Prefer ``javascript(_:)``.)
        case javascriptScope(Document<Bytes>, UTF8<Bytes>)
        /// The MongoDB max-key.
        case max
        /// UTC milliseconds since the Unix epoch.
        case millisecond(Millisecond)
        /// The MongoDB min-key.
        case min
        /// An explicit null.
        case null
        /// A MongoDB database pointer. This variant is maintained for
        /// backward-compatibility with older versions of BSON and
        /// should not be generated. (Prefer ``id(_:)``.)
        case pointer(UTF8<Bytes>, Identifier)
        /// A regex.
        case regex(Regex)
        /// A UTF-8 string, possibly containing invalid code units.
        /// The payload is a library type to permit efficient document traversal.
        case string(UTF8<Bytes>)
        /// A 64-bit unsigned integer.
        ///
        /// MongoDB also uses this type internally to represent timestamps.
        case uint64(UInt64)
    }
}
extension BSON.Value
{
    /// The type of this variant value.
    @inlinable public
    var type:BSON
    {
        switch self
        {
        case .document:         return .document
        case .tuple:            return .tuple
        case .binary:           return .binary
        case .bool:             return .bool
        case .decimal128:       return .decimal128
        case .double:           return .double
        case .id:               return .id
        case .int32:            return .int32
        case .int64:            return .int64
        case .javascript:       return .javascript
        case .javascriptScope:  return .javascriptScope
        case .max:              return .max
        case .millisecond:      return .millisecond
        case .min:              return .min
        case .null:             return .null
        case .pointer:          return .pointer
        case .regex:            return .regex
        case .string:           return .string
        case .uint64:           return .uint64
        }
    }
    /// The size of this variant value when encoded.
    @inlinable public
    var size:Int
    {
        switch self
        {
        case .document(let document):
            return document.size
        case .tuple(let tuple):
            return tuple.size
        case .binary(let binary):
            return binary.size
        case .bool:
            return 1
        case .decimal128:
            return 16
        case .double:
            return 8
        case .id:
            return 12
        case .int32:
            return 4
        case .int64:
            return 8
        case .javascript(let utf8):
            return utf8.size
        case .javascriptScope(let scope, let utf8):
            return 4 + utf8.size + scope.size
        case .max:
            return 0
        case .millisecond:
            return 8
        case .min:
            return 0
        case .null:
            return 0
        case .pointer(let database, _):
            return 12 + database.size
        case .regex(let regex):
            return regex.size
        case .string(let string):
            return string.size
        case .uint64:
            return 8
        }
    }
}
extension BSON.Value
{
    /// Parses a variant BSON value from a collection of bytes, 
    /// assuming it is of the specified `variant` type.
    // @inlinable public
    // init<Source>(parsing source:Source, as variant:BSON) throws
    //     where Source:RandomAccessCollection<UInt8>, Source.SubSequence == Bytes
    // {
    //     var input:BSON.Input<Source> = .init(source)
    //     self = try input.parse(variant: variant)
    //     try input.finish()
    // }
}
extension BSON.Value
{
    /// Performs a type-aware equivalence comparison.
    /// If both operands are a ``document(_:)`` (or ``tuple(_:)``), performs a recursive
    /// type-aware comparison by calling `BSON//Document.~~(_:_:)`.
    /// If both operands are a ``string(_:)``, performs unicode-aware string comparison.
    /// If both operands are a ``double(_:)``, performs floating-point-aware
    /// numerical comparison.
    ///
    /// >   Warning:
    ///     Comparison of ``decimal128(_:)`` values uses bitwise equality. This library does
    ///     not support decimal equivalence.
    ///
    /// >   Warning:
    ///     Comparison of ``millisecond(_:)`` values uses integer equality. This library does
    ///     not support calendrical equivalence.
    /// 
    /// >   Note:
    ///     The embedded document in the deprecated `javascriptScope(_:_:)` variant
    ///     also receives type-aware treatment.
    /// 
    /// >   Note:
    ///     The embedded UTF-8 string in the deprecated `pointer(_:_:)` variant
    ///     also receives type-aware treatment.
    @inlinable public static
    func ~~ (lhs:Self, rhs:BSON.Value<some RandomAccessCollection<UInt8>>) -> Bool
    {
        switch (lhs, rhs)
        {
        case (.document     (let lhs), .document    (let rhs)):
            return lhs ~~ rhs
        case (.tuple        (let lhs), .tuple       (let rhs)):
            return lhs ~~ rhs
        case (.binary       (let lhs), .binary      (let rhs)):
            return lhs == rhs
        case (.bool         (let lhs), .bool        (let rhs)):
            return lhs == rhs
        case (.decimal128   (let lhs), .decimal128  (let rhs)):
            return lhs == rhs
        case (.double       (let lhs), .double      (let rhs)):
            return lhs == rhs
        case (.id           (let lhs), .id          (let rhs)):
            return lhs == rhs
        case (.int32        (let lhs), .int32       (let rhs)):
            return lhs == rhs
        case (.int64        (let lhs), .int64       (let rhs)):
            return lhs == rhs
        case (.javascript   (let lhs), .javascript  (let rhs)):
            return lhs == rhs
        case (.javascriptScope(let lhs, let lhsCode), .javascriptScope(let rhs, let rhsCode)):
            return lhsCode == rhsCode && lhs ~~ rhs
        case (.max,                     .max):
            return true
        case (.millisecond  (let lhs), .millisecond (let rhs)):
            return lhs.value == rhs.value
        case (.min,                     .min):
            return true
        case (.null,                    .null):
            return true
        case (.pointer(let lhs, let lhsID), .pointer(let rhs, let rhsID)):
            return lhsID == rhsID && lhs == rhs
        case (.regex        (let lhs), .regex       (let rhs)):
            return lhs == rhs
        case (.string       (let lhs), .string      (let rhs)):
            return lhs == rhs
        case (.uint64       (let lhs), .uint64      (let rhs)):
            return lhs == rhs
        
        default:
            return false
        }
    }
}
extension BSON.Value:Equatable
{
}
extension BSON.Value:Sendable where Bytes:Sendable, Bytes.SubSequence:Sendable
{
}
extension BSON.Value:ExpressibleByStringLiteral,
    ExpressibleByArrayLiteral,
    ExpressibleByExtendedGraphemeClusterLiteral, 
    ExpressibleByUnicodeScalarLiteral,
    ExpressibleByDictionaryLiteral
    where Bytes:RangeReplaceableCollection<UInt8>
{
    @inlinable public
    init(stringLiteral:String)
    {
        self = .string(stringLiteral)
    }
    @inlinable public
    init(arrayLiteral:Self...)
    {
        self = .tuple(.init(arrayLiteral))
    }
    @inlinable public
    init(dictionaryLiteral:(String, Self)...)
    {
        self = .document(.init(dictionaryLiteral))
    }
    /// Recursively parses and re-encodes any embedded documents (and tuple-documents)
    /// in this variant value.
    @inlinable public
    func canonicalized() throws -> Self
    {
        switch self
        {
        case    .document(let document):
            return .document(try document.canonicalized())
        case    .tuple(let tuple):
            return .tuple(try tuple.canonicalized())
        case    .binary,
                .bool,
                .decimal128,
                .double,
                .id,
                .int32,
                .int64,
                .javascript:
            return self
        case    .javascriptScope(let scope, let utf8):
            return .javascriptScope(try scope.canonicalized(), utf8)
        case    .max,
                .millisecond,
                .min,
                .null,
                .pointer,
                .regex,
                .string,
                .uint64:
            return self
        }
    }

    /// Copies the UTF-8 code units backing the given string into a
    /// variant of ``case string(_:)``.
    ///
    /// >   Complexity: O(*n*), where *n* is the length of the string.
    @inlinable public static
    func string(_ string:some StringProtocol) -> Self
    {
        .string(.init(string))
    }
    @inlinable public static
    func javascript(_ string:some StringProtocol) -> Self
    {
        .javascript(.init(string))
    }
    @inlinable public static
    func javascriptScope(_ scope:BSON.Document<Bytes>, _ string:some StringProtocol) -> Self
    {
        .javascriptScope(scope, .init(string))
    }
}
extension BSON.Value:ExpressibleByFloatLiteral
{
    @inlinable public
    init(floatLiteral:Double)
    {
        self = .double(floatLiteral)
    }
}
extension BSON.Value:ExpressibleByIntegerLiteral
{
    /// Creates an instance initialized to the specified integer value.
    ///
    /// Although MongoDB uses ``Int32`` as its default integer type,
    /// this library infers integer literals to be of type ``Int`` for
    /// consistency with the rest of the Swift language.
    @inlinable public
    init(integerLiteral:Int)
    {
        self = .int64(Int64.init(integerLiteral))
    }
}
extension BSON.Value:ExpressibleByBooleanLiteral
{
    @inlinable public
    init(booleanLiteral:Bool)
    {
        self = .bool(booleanLiteral)
    }
}

extension BSON.Value:CustomStringConvertible
{
    public
    var description:String
    {
        switch self
        {
        case .document(let document):
            return ".document(\(document))"
        case .tuple(let tuple):
            return ".tuple(\(tuple))"
        case .binary(let binary):
            return ".binary(\(binary))"
        case .bool(let bool):
            return ".bool(\(bool))"
        case .decimal128(let decimal128):
            return ".decimal128(\(decimal128))"
        case .double(let double):
            return ".double(\(double))"
        case .id(let id):
            return ".id(\(id))"
        case .int32(let int32):
            return ".int32(\(int32))"
        case .int64(let int64):
            return ".int64(\(int64))"
        case .javascript(let javascript):
            return ".javascript(\(javascript))"
        case .javascriptScope(let scope, let javascript):
            return ".javascriptScope(\(scope), \(javascript))"
        case .max:
            return ".max"
        case .millisecond(let millisecond):
            return ".millisecond(\(millisecond))"
        case .min:
            return ".min"
        case .null:
            return ".null"
        case .pointer(let database, let id):
            return ".pointer(\(database), \(id))"
        case .regex(let regex):
            return ".regex(\(regex))"
        case .string(let string):
            return ".string(\(string))"
        case .uint64(let uint64):
            return ".uint64(\(uint64))"
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
    // /// Indicates if this variant is ``max``.
    // @inlinable public 
    // func `is`(_:BSON.Max.Type) -> Bool
    // {
    //     switch self 
    //     {
    //     case .max:  return true 
    //     default:    return false
    //     }
    // }
    // /// Indicates if this variant is ``min``.
    // @inlinable public 
    // func `is`(_:BSON.Min.Type) -> Bool
    // {
    //     switch self 
    //     {
    //     case .min:  return true 
    //     default:    return false
    //     }
    // }

    /// Attempts to load an instance of ``Bool`` from this variant.
    /// 
    /// -   Returns:
    ///     The payload of this variant if it matches ``case bool(_:)``, 
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
    ///     if it matches one of ``case int32(_:)``, ``case int64(_:)``, or
    ///     ``case uint64(_:)``, and it can be represented exactly by [`T`]();
    ///     [`nil`]() otherwise.
    ///
    /// The ``case decimal128(_:)``, ``case double(_:)``, and ``case millisecond(_:)``
    /// variants will *not* match.
    ///
    /// This method reports failure in two ways — it returns [`nil`]() on a type 
    /// mismatch, and it [`throws`]() an ``IntegerOverflowError`` if this variant 
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
    /// Attempts to load an instance of some ``BinaryFloatingPoint`` type from
    /// this variant.
    /// 
    /// -   Returns:
    ///     The closest value of [`T`]() to the payload of this 
    ///     variant if it matches ``case double(_:)``, [`nil`]() otherwise.
    @inlinable public 
    func `as`<Fraction>(_:Fraction.Type) -> Fraction?
        where Fraction:BinaryFloatingPoint
    {
        switch self 
        {
        case .double(let double):   return .init(double)
        default:                    return nil 
        }
    }
    /// Attempts to load an instance of ``Decimal128`` from this variant.
    /// 
    /// -   Returns:
    ///     The payload of this variant if it matches ``case decimal128(_:)``, 
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
    /// Attempts to load an instance of ``Identifier`` from this variant.
    /// 
    /// -   Returns:
    ///     The payload of this variant if it matches ``case id(_:)`` or
    ///     ``case pointer(_:_:)``, [`nil`]() otherwise.
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
    /// Attempts to load an instance of ``Millisecond`` from this variant.
    /// 
    /// -   Returns:
    ///     The payload of this variant if it matches ``case millisecond(_:)``,
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
    /// Attempts to load an instance of ``Regex`` from this variant.
    /// 
    /// -   Returns:
    ///     The payload of this variant if it matches ``case regex(_:)``,
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
    /// Attempts to load an instance of ``String`` from this variant. Its UTF-8 code
    /// units will be validated (and repaired if needed).
    /// 
    /// -   Returns:
    ///     The payload of this variant, decoded to a ``String``, if it matches
    ///     ``case string(_:)``, [`nil`]() otherwise.
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
    @inlinable public 
    func `as`(_:Character.Type) -> Character?
    {
        if  let string:String = self.as(String.self),
                string.startIndex < string.endIndex,
                string.index(after: string.startIndex) == string.endIndex
        {
            return string[string.startIndex]
        }
        else
        {
            return nil
        }
    }
    @inlinable public 
    func `as`(_:Unicode.Scalar.Type) -> Unicode.Scalar?
    {
        if  let string:String.UnicodeScalarView = self.as(String.self)?.unicodeScalars,
                string.startIndex < string.endIndex,
                string.index(after: string.startIndex) == string.endIndex
        {
            return string[string.startIndex]
        }
        else
        {
            return nil
        }
    }
}
extension BSON.Value
{
    /// Attempts to load an explicit ``null`` from this variant.
    /// 
    /// -   Returns:
    ///     [`()`]() if this variant is ``null``, [`nil`]() otherwise.
    @inlinable public 
    var null:Void?
    {
        self.is(Void.self) ? () : nil
    }
    /// Attempts to load a ``max`` key from this variant.
    /// 
    /// -   Returns:
    ///     ``Max.max`` if this variant is ``max``, [`nil`]() otherwise.
    @inlinable public 
    var max:BSON.Max?
    {
        switch self 
        {
        case .max:  return .init()
        default:    return nil
        }
    }
    /// Attempts to load a ``min`` key from this variant.
    /// 
    /// -   Returns:
    ///     ``Min.min`` if this variant is ``min``, [`nil`]() otherwise.
    @inlinable public 
    var min:BSON.Min?
    {
        switch self 
        {
        case .min:  return .init()
        default:    return nil
        }
    }
}
extension BSON.Value
{
    /// Attempts to unwrap a binary array from this variant.
    /// 
    /// -   Returns: The payload of this variant if it matches ``case binary(_:)``,
    ///     [`nil`]() otherwise.
    /// 
    /// >   Complexity: O(1).
    @inlinable public 
    var binary:BSON.Binary<Bytes>?
    {
        switch self 
        {
        case .binary(let binary):
            return binary
        default:
            return nil 
        }
    }
    /// Attempts to unwrap a document from this variant.
    /// 
    /// -   Returns: The payload of this variant if it matches ``case document(_:)``
    ///     or ``case tuple(_:)``, [`nil`]() otherwise.
    /// 
    /// If the variant was a tuple, the string keys of the returned document are likely
    /// (but not guaranteed) to be the tuple indices encoded as base-10 strings, without
    /// leading zeros.
    /// 
    /// >   Complexity: O(1).
    @inlinable public 
    var document:BSON.Document<Bytes>?
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
    /// Attempts to unwrap a tuple from this variant.
    /// 
    /// -   Returns:
    ///     The payload of this variant if it matches ``case tuple(_:)``,
    ///     [`nil`]() otherwise.
    ///
    /// >   Complexity: O(1).
    @inlinable public 
    var tuple:BSON.Tuple<Bytes>?
    {
        switch self 
        {
        case .tuple(let tuple): return tuple
        default:                return nil
        }
    }
    /// Attempts to unwrap an instance of ``UTF8`` from this variant. Its UTF-8 code
    /// units will *not* be validated, which allowes this method to return in
    /// constant time.
    /// 
    /// -   Returns:
    ///     The payload of this variant if it matches ``case string(_:)``,
    ///     [`nil`]() otherwise.
    ///
    /// >   Complexity: O(1).
    ///
    /// To obtain a swift ``String``, use the ``as(_:)`` method.
    @inlinable public 
    var utf8:BSON.UTF8<Bytes>?
    {
        switch self 
        {
        case .string(let string):   return string
        default:                    return nil
        }
    }
}
