/// A BSON value that supports random-access traversal.
public
protocol TraversableBSON<Bytes>
{
    /// The backing storage used by this type. It is recommended that 
    /// implementations satisfy this with generics.
    associatedtype Bytes:RandomAccessCollection<UInt8>
    /// The length header associated with this type. This is specified as an
    /// associated type, so that it can be independent of the ``Bytes`` type.
    associatedtype Header:TraversableBSONHeader

    /// Receives a collection of bytes encompassing the body and any trailers
    /// backing this value, but not including the length header.
    /// The implementation may slice the argument, but should do so in O(1) time.
    init(slicing:Bytes) throws
}
public
protocol TraversableBSONHeader
{
    /// The number of (conceptual) bytes in this length header type.
    /// This will be zero if the length header does not include its own length,
    /// and can be negative if the type it is associated with has a trailer.
    static
    var size:Int { get }
}
