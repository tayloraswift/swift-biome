public
enum BSON 
{
    @frozen public
    enum Variant<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        case document(Document<Bytes>)
        case array(Document<Bytes>)

        case binary(Binary<Bytes>)

        case bool(Bool)
        case datetime(Int64)
        case decimal128(Decimal128)
        case double(Double)
        case int32(Int32)
        case int64(Int64)
        case javascript(UTF8<Bytes>, scope:Document<Bytes>? = nil)
        case max
        case millisecond(Int64)
        case min 
        case null
        case object(Object)
        case pointer(String, Object)
        case regex(Regex)
        case string(String)
        case symbol(UTF8<Bytes>)
        case uint64(UInt64)
    }

    public
    enum BooleanError:Error
    {
        case invalid(UInt8)
    }
    public
    struct TypeError:Error
    {
        public
        let code:UInt8
    }
    public
    enum ParsingError:Error
    {
        case trailed(bytes:Int)
        case incomplete
    }
}
