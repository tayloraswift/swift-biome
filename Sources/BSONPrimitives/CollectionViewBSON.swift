import BSON

public
protocol CollectionViewBSON<Bytes>
{
    /// The backing storage used by this type. It is recommended that 
    /// implementations satisfy this with generics.
    associatedtype Bytes:RandomAccessCollection<UInt8>

    init(_:BSON.Value<Bytes>) throws
}
