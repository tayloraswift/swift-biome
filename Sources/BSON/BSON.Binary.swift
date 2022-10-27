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
    }
}
extension BSON.Binary:TraversableBSON
{
    @inlinable public static
    var headerBytes:Int
    {
        -1
    }
    @inlinable public
    init(_ bytes:Bytes) throws
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

        self.bytes = bytes.dropFirst()
        self.subtype = subtype
    }
}
