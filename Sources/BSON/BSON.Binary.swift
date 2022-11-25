import BSONTraversal

extension BSON
{
    /// Represents a binary array header in the library’s static type system.
    @frozen public
    enum BinaryFrame:VariableLengthBSONFrame
    {
        /// A binary array header starts its count after skipping the interceding
        /// subtype byte. Therefore its conceptual prefix size is -1.
        public static
        let prefix:Int = -1
        public static
        let suffix:Int = 0
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
        let bytes:Bytes
        /// The subtype of this binary array.
        public
        let subtype:BinarySubtype

        @inlinable public
        init(subtype:BinarySubtype, bytes:Bytes)
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
extension BSON.Binary:Sendable where Bytes:Sendable
{
}
extension BSON.Binary:VariableLengthBSON where Bytes.SubSequence == Bytes
{
    public
    typealias Frame = BSON.BinaryFrame
    
    /// Removes the first element of the argument, attempts to cast it to a
    /// ``BinarySubtype``, and stores the remainder in ``bytes``.
    ///
    /// If the subtype is the deprecated generic subtype (code [`0x02`]()),
    /// the inner length header will be stripped from ``bytes`` and ignored.
    ///
    /// >   Complexity: O(1)
    @inlinable public
    init(slicing bytes:Bytes) throws
    {
        guard let code:UInt8 = bytes.first
        else
        {
            throw BSON.InputError.init(expected: .bytes(1))
        }
        guard let subtype:BSON.BinarySubtype = .init(rawValue: code)
        else
        {
            throw BSON.BinarySubtypeError.init(invalid: code)
        }

        let start:Bytes.Index = bytes.index(after: bytes.startIndex)
        if code != 0x02
        {
            self.init(subtype: subtype, bytes: bytes[start...])
        }
        // special handling for legacy binary format 0x02
        else if let start:Bytes.Index = bytes.index(start, offsetBy: 4,
                    limitedBy: bytes.endIndex)
        {
            self.init(subtype: subtype, bytes: bytes.suffix(from: start))
        }
        else
        {
            throw BSON.InputError.init(expected: .bytes(4), 
                encountered: bytes.distance(from: start, to: bytes.endIndex))
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
