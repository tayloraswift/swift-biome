
extension BSON.Value
{
    @inlinable public static
    func document(_ document:BSON.Document<Bytes>?) -> Self?
    {
        document.map(Self.document(_:))
    }
    @inlinable public static
    func tuple(_ tuple:BSON.Tuple<Bytes>?) -> Self?
    {
        tuple.map(Self.tuple(_:))
    }
    @inlinable public static
    func binary(_ binary:BSON.Binary<Bytes>?) -> Self?
    {
        binary.map(Self.binary(_:))
    }
    @inlinable public static
    func bool(_ bool:Bool?) -> Self?
    {
        bool.map(Self.bool(_:))
    }
    @inlinable public static
    func decimal128(_ decimal128:BSON.Decimal128?) -> Self?
    {
        decimal128.map(Self.decimal128(_:))
    }
    @inlinable public static
    func double(_ double:Double?) -> Self?
    {
        double.map(Self.double(_:))
    }
    @inlinable public static
    func id(_ id:BSON.Identifier?) -> Self?
    {
        id.map(Self.id(_:))
    }
    @inlinable public static
    func int32(_ int32:Int32?) -> Self?
    {
        int32.map(Self.int32(_:))
    }
    @inlinable public static
    func int64(_ int64:Int64?) -> Self?
    {
        int64.map(Self.int64(_:))
    }
    @inlinable public static
    func javascript(_ javascript:BSON.UTF8<Bytes>?) -> Self?
    {
        javascript.map(Self.javascript(_:))
    }
    @inlinable public static
    func millisecond(_ millisecond:BSON.Millisecond?) -> Self?
    {
        millisecond.map(Self.millisecond(_:))
    }
    @inlinable public static
    func regex(_ regex:BSON.Regex?) -> Self?
    {
        regex.map(Self.regex(_:))
    }
    @inlinable public static
    func string(_ string:BSON.UTF8<Bytes>?) -> Self?
    {
        string.map(Self.string(_:))
    }
    @inlinable public static
    func uint64(_ uint64:UInt64?) -> Self?
    {
        uint64.map(Self.uint64(_:))
    }
}
extension BSON.Value where Bytes:RangeReplaceableCollection<UInt8>
{
    @inlinable public static
    func string(_ string:(some StringProtocol)?) -> Self?
    {
        string.map(Self.string(_:))
    }
    @inlinable public static
    func javascript(_ javascript:(some StringProtocol)?) -> Self?
    {
        javascript.map(Self.javascript(_:))
    }
}
