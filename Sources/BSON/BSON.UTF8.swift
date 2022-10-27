import BSONTraversal

extension BSON
{
    /// A BSON UTF-8 string. This string is allowed to contain null bytes.
    @frozen public
    struct UTF8<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        /// The UTF-8 code units backing this string. This collection does *not*
        /// include the trailing null byte that typically appears when this value
        /// occurs inline in a document.
        public 
        let bytes:Bytes.SubSequence
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
    @inlinable public static
    var headerBytes:Int
    {
        0
    }
    @inlinable public
    init(_ bytes:Bytes)
    {
        // `dropLast`, because `self.bytes` contains a trailing null byte.
        self.bytes = bytes.dropLast()
    }
}
