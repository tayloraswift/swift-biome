extension BSON
{
    /// A BSON variant value.
    @frozen public
    enum Variant<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        /// A general embedded document.
        case document(Document<Bytes>)
        /// An embedded array-document.
        case array(Array<Bytes>)
        /// A binary array.
        case binary(Binary<Bytes>)

        case bool(Bool)
        case decimal128(Decimal128)
        case double(Double)
        case id(Identifier)
        case int32(Int32)
        case int64(Int64)
        /// Javascript code.
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
        case null
        /// A MongoDB database pointer. This variant is maintained for
        /// backward-compatibility with older versions of BSON and
        /// should not be generated. (Prefer ``id(_:)``.)
        case pointer(String, Identifier)
        case regex(Regex)
        case string(String)
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
        case .array:            return .array
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
        case .array(let array):
            return array.size
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
            return 5 + database.utf8.count
        case .regex(let regex):
            return regex.size
        case .string(let string):
            return 5 + string.utf8.count
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
extension BSON.Variant where Bytes.SubSequence:Equatable
{
    @inlinable public static
    func =~= (lhs:Self, rhs:Self) -> Bool
    {
        switch (lhs, rhs)
        {
        case (.document     (let lhs), .document    (let rhs)):
            return lhs =~= rhs
        case (.array        (let lhs), .array       (let rhs)):
            return lhs =~= rhs
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
            return lhsCode == rhsCode && lhs =~= rhs
        case (.max,                     .max):
            return true
        case (.millisecond  (let lhs), .millisecond (let rhs)):
            return lhs == rhs
        case (.min,                     .min):
            return true
        case (.null,                    .null):
            return true
        case (.pointer(let lhs, let lhsID), .pointer(let rhs, let rhsID)):
            return (lhs, lhsID) == (rhs, rhsID)
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
extension BSON.Variant:Equatable where Bytes:Equatable, Bytes.SubSequence:Equatable
{
}
extension BSON.Variant:Sendable where Bytes:Sendable, Bytes.SubSequence:Sendable
{
}
extension BSON.Variant:ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral
    where Bytes:RangeReplaceableCollection
{
    @inlinable public
    init(arrayLiteral:Self...)
    {
        self = .array(.init(arrayLiteral))
    }
    @inlinable public
    init(dictionaryLiteral:(String, Self)...)
    {
        self = .document(.init(dictionaryLiteral))
    }
}
extension BSON.Variant:ExpressibleByStringLiteral
{
    @inlinable public
    init(stringLiteral:String)
    {
        self = .string(stringLiteral)
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
