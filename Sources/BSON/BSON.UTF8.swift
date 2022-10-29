import BSONTraversal

extension BSON
{
    /// The payload of a UTF-8 string did not contain the expected amount of data.
    public
    enum EndOfUTF8Error:Equatable, Error
    {
        /// The payload of a UTF-8 string was missing its trailing null byte.
        case unexpected
    }
}
extension BSON.EndOfUTF8Error:CustomStringConvertible
{
    public 
    var description:String
    {
        switch self
        {
        case .unexpected:
            return "missing trailing null byte after utf-8 string"
        }
    }
}
extension BSON
{
    /// A BSON UTF-8 string. This string is allowed to contain null bytes.
    @frozen public
    struct UTF8<Bytes> where Bytes:BidirectionalCollection<UInt8>
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
    /// Performs an exact byte-wise comparison on two UTF-8 strings.
    /// This operator does *not* take into account unicode canonical equivalence.
    @inlinable public static
    func == (lhs:Self, rhs:BSON.UTF8<some BidirectionalCollection<UInt8>>) -> Bool
    {
        lhs.bytes.elementsEqual(rhs.bytes)
    }
}
extension BSON.UTF8:Sendable where Bytes.SubSequence:Sendable
{
}
extension BSON.UTF8<String.UTF8View>
{
    @inlinable public
    init<String>(_ string:String) where String:StringProtocol, String.SubSequence == Substring
    {
        self.init(string[...].utf8)
    }
}
extension BSON.UTF8<String.UTF8View>:ExpressibleByStringLiteral, 
    ExpressibleByExtendedGraphemeClusterLiteral, 
    ExpressibleByUnicodeScalarLiteral
{
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
extension BSON.UTF8:TraversableBSON where Bytes:RandomAccessCollection<UInt8>
{
    @inlinable public static
    var headerSize:Int
    {
        0
    }
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
            throw BSON.EndOfUTF8Error.unexpected
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
