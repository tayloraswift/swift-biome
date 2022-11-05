import BSONTraversal

extension BSON
{
    @frozen public
    enum UTF8Header:TraversableBSONHeader
    {
        public static
        let size:Int = 0
    }
}
extension BSON
{
    /// A BSON UTF-8 string. This string is allowed to contain null bytes.
    ///
    /// This type can wrap potentially-invalid UTF-8 data, therefore it
    /// is not backed by an instance of ``String``. Moreover, it (and not ``String``)
    /// is the payload of ``BSON/Variant.string(_:)`` to ensure that long string
    /// fields can be traversed in constant time.
    ///
    /// To convert a UTF-8 string to a native Swift ``String`` (repairing invalid UTF-8),
    /// use the ``description`` property.
    @frozen public
    struct UTF8<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        /// The UTF-8 code units backing this string. This collection does *not*
        /// include the trailing null byte that typically appears when this value
        /// occurs inline in a document.
        public 
        let bytes:Bytes.SubSequence

        @inlinable public
        init(_ bytes:Bytes.SubSequence)
        {
            self.bytes = bytes
        }
    }
}
extension BSON.UTF8:Equatable
{
    /// Performs a unicode-aware string comparison on two UTF-8 strings.
    @inlinable public static
    func == (lhs:Self, rhs:BSON.UTF8<some RandomAccessCollection<UInt8>>) -> Bool
    {
        lhs.description == rhs.description
    }
}
extension BSON.UTF8:Sendable where Bytes.SubSequence:Sendable
{
}
extension BSON.UTF8:ExpressibleByStringLiteral,
    ExpressibleByExtendedGraphemeClusterLiteral, 
    ExpressibleByUnicodeScalarLiteral
    where Bytes:RangeReplaceableCollection<UInt8>
{
    @inlinable public
    init(_ string:some StringProtocol)
    {
        self.init(.init(string.utf8))
    }
    @inlinable public
    init(stringLiteral:String)
    {
        self.init(stringLiteral)
    }
}

extension BSON.UTF8:CustomStringConvertible
{
    /// Decodes ``bytes`` into a string. This is the preferred way to
    /// get the string value of this UTF-8 string.
    ///
    /// >   Complexity: O(*n*), where *n* is the length of the string.
    @inlinable public
    var description:String
    {
        .init(decoding: self.bytes, as: Unicode.UTF8.self)
    }
}
extension BSON.UTF8:TraversableBSON
{
    public
    typealias Header = BSON.UTF8Header

    /// Removes the last element of the argument, and stores it in ``bytes``.
    ///
    /// The last element is expected to have been a null byte, but this is
    /// not enforced.
    ///
    /// >   Complexity: O(1)
    @inlinable public
    init(slicing bytes:Bytes) throws
    {
        if bytes.startIndex < bytes.endIndex
        {
            self.init(bytes.prefix(upTo: bytes.index(before: bytes.endIndex)))
        }
        else
        {
            throw BSON.InputError.init(expected: .byte(0x00))
        }
    }
}

extension BSON.UTF8
{
    /// The length that would be encoded in this string’s prefixed header.
    /// Equal to [`self.bytes.count + 1`]().
    @inlinable public
    var header:Int32
    {
        Int32.init(self.bytes.count) + 1
    }
    /// The size of this string when encoded with its header and trailing null byte.
    /// This is *not* the length encoded in the header itself.
    @inlinable public
    var size:Int
    {
        5 + self.bytes.count
    }
}
