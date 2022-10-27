public
protocol TraversableBSON<Bytes>
{
    associatedtype Bytes:RandomAccessCollection<UInt8>

    init(_:Bytes) throws
    static
    var headerBytes:Int { get }
}
