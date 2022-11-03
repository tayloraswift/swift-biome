extension BSON
{
    /// A BSON variant value.
    @frozen public
    enum Variant<Bytes> where Bytes:RandomAccessCollection<UInt8>
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
        case millisecond(Int64)
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
extension BSON.Variant
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
extension BSON.Variant
{
    /// Parses a variant BSON value from a collection of bytes, 
    /// assuming it is of the specified `variant` type.
    @inlinable public
    init<Source>(parsing source:Source, as variant:BSON) throws
        where Source:RandomAccessCollection<UInt8>, Source.SubSequence == Bytes
    {
        var input:BSON.Input<Source> = .init(source)
        self = try input.parse(variant: variant)
        try input.finish()
    }
}
extension BSON.Variant
{
    /// Performs a type-aware equivalence comparison.
    /// If both operands are a ``document(_:)`` (or ``tuple(_:)``), performs a recursive
    /// type-aware comparison by calling `BSON//Document.~~(_:_:)`.
    /// If both operands are a ``string(_:)``, performs unicode-aware string comparison.
    /// If both operands are a ``double(_:)``, performs floating-point-aware
    /// numerical comparison.
    /// 
    /// >   Note:
    ///     The embedded document in the deprecated `javascriptScope(_:_:)` variant
    ///     also receives type-aware treatment.
    /// 
    /// >   Note:
    ///     The embedded UTF-8 string in the deprecated `pointer(_:_:)` variant
    ///     also receives type-aware treatment.
    @inlinable public static
    func ~~ (lhs:Self, rhs:BSON.Variant<some RandomAccessCollection<UInt8>>) -> Bool
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
            return lhs == rhs
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
extension BSON.Variant:Equatable
{
}
extension BSON.Variant:Sendable where Bytes:Sendable, Bytes.SubSequence:Sendable
{
}
extension BSON.Variant:ExpressibleByStringLiteral,
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

    @inlinable public static
    func string(_ string:some StringProtocol) -> Self
    {
        .string(.init(.init(string.utf8)))
    }
    @inlinable public static
    func javascript(_ string:some StringProtocol) -> Self
    {
        .javascript(.init(.init(string.utf8)))
    }
    @inlinable public static
    func javascriptScope(_ scope:BSON.Document<Bytes>, _ string:some StringProtocol) -> Self
    {
        .javascriptScope(scope, .init(.init(string.utf8)))
    }
}
extension BSON.Variant:ExpressibleByFloatLiteral
{
    @inlinable public
    init(floatLiteral:Double)
    {
        self = .double(floatLiteral)
    }
}
extension BSON.Variant:ExpressibleByIntegerLiteral
{
    @inlinable public
    init(integerLiteral:Int64)
    {
        self = .int64(integerLiteral)
    }
}
extension BSON.Variant:ExpressibleByBooleanLiteral
{
    @inlinable public
    init(booleanLiteral:Bool)
    {
        self = .bool(booleanLiteral)
    }
}
