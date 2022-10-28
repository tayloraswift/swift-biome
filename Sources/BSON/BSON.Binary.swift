import BSONTraversal

extension BSON
{
    /// A BSON binary array.
    @frozen public
    struct Binary<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        /// The contents of this binary array. This collection does *not*
        /// include the leading subtype byte.
        public 
        let bytes:Bytes.SubSequence
        /// The subtype of this binary array.
        public 
        let subtype:BinarySubtype

        @inlinable public
        init(subtype:BinarySubtype, bytes:Bytes.SubSequence)
        {
            self.subtype = subtype
            self.bytes = bytes
        }
    }
}
extension BSON.Binary:Equatable where Bytes.SubSequence:Equatable
{
}
extension BSON.Binary:Sendable where Bytes.SubSequence:Sendable
{
}
extension BSON.Binary:TraversableBSON
{
    @inlinable public static
    var headerSize:Int
    {
        -1
    }
    /// Removes the first element of the argument, attempts to cast it to a
    /// ``BinarySubtype``, and stores the remainder in ``bytes``.
    ///
    /// >   Complexity: O(1)
    @inlinable public
    init(slicing bytes:Bytes) throws
    {
        guard let subtype:UInt8 = bytes.first
        else
        {
            throw BSON.BinarySubtypeError.missing
        }
        guard let subtype:BSON.BinarySubtype = .init(rawValue: subtype)
        else
        {
            throw BSON.BinarySubtypeError.invalid(subtype)
        }

        self.init(subtype: subtype, bytes: bytes.dropFirst())
    }
}
extension BSON.Binary
{
    /// The length that would be encoded in this binary array’s prefixed header.
    /// Equal to [`self.bytes.count`]().
    @inlinable public
    var header:Int32
    {
        .init(self.bytes.count)
    }
    /// The size of this binary array when encoded with its header.
    /// This is *not* the length encoded in the header itself.
    @inlinable public
    var size:Int
    {
        5 + self.bytes.count
    }
}
