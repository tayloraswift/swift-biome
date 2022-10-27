public
enum BSON 
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
        case int32(Int32)
        case int64(Int64)
        /// Javascript code. The `scope` field is maintained for 
        /// backward-compatibility with older versions of BSON and 
        /// should not be generated.
        case javascript(UTF8<Bytes>, scope:Document<Bytes>? = nil)
        /// The MongoDB max-key.
        case max
        /// UTC milliseconds since the Unix epoch.
        case millisecond(Int64)
        /// The MongoDB min-key.
        case min
        case null
        case object(Object)
        /// A MongoDB database pointer. This variant is maintained for
        /// backward-compatibility with older versions of BSON and
        /// should not be generated. (Prefer ``object(_:)``.)
        case pointer(String, Object)
        case regex(Regex)
        case string(String)
        case uint64(UInt64)
    }

    /// A byte encoding a boolean value was not [`0`]() or [`1`]().
    public
    enum BooleanError:Error
    {
        case invalid(UInt8)
    }
    /// A variant code did not encode a valid BSON type.
    public
    struct TypeError:Error
    {
        public
        let code:UInt8
    }
}
