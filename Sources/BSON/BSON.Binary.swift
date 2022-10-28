import BSONTraversal

extension BSON
{
    /// The payload of a binary array was malformed. This error is only generated
    /// by legacy binary subtypes; it will not be thrown when slicing modern binary arrays.
    public
    enum EndOfBinaryError:Equatable, Error
    {
        /// The payload of a binary array (of legacy subtype `0x02`) was missing its header.
        case unexpected
    }
}
extension BSON.EndOfBinaryError:CustomStringConvertible
{
    public 
    var description:String
    {
        switch self
        {
        case .unexpected:
            return "missing length header for legacy binary subtype"
        }
    }
}
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
extension BSON.Binary:Equatable
{
    /// Performs an exact byte-wise comparison on two binary arrays.
    /// The subtypes must match as well.
    @inlinable public static
    func == (lhs:Self, rhs:BSON.Binary<some RandomAccessCollection<UInt8>>) -> Bool
    {
        lhs.subtype == rhs.subtype &&
        lhs.bytes.elementsEqual(rhs.bytes)
    }
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
        guard let code:UInt8 = bytes.first
        else
        {
            throw BSON.BinarySubtypeError.missing
        }
        guard let subtype:BSON.BinarySubtype = .init(rawValue: code)
        else
        {
            throw BSON.BinarySubtypeError.invalid(code)
        }
        if code != 0x02
        {
            self.init(subtype: subtype, bytes: bytes.dropFirst())
        }
        // special handling for legacy binary format 0x02
        else if let start:Bytes.Index = bytes.index(bytes.startIndex, offsetBy: 5, 
            limitedBy: bytes.endIndex)
        {
            self.init(subtype: subtype, bytes: bytes.suffix(from: start))
        }
        else
        {
            throw BSON.EndOfBinaryError.unexpected
        }
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
