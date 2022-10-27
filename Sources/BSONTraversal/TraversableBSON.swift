/// A BSON value that supports random-access traversal.
public
protocol TraversableBSON<Bytes>
{
    associatedtype Bytes:RandomAccessCollection<UInt8>

    /// Receives a collection of bytes encompassing the body and any trailers
    /// backing this value, but not including the length header.
    init(_:Bytes) throws
    /// The number of (conceptual) bytes in the length header associated with this type.
    /// This will be zero if the length header does not include its own length,
    /// and can be negative if this type has a trailer.
    static
    var headerBytes:Int { get }
}
