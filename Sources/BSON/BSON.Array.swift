import BSONTraversal

extension BSON
{
    /// A BSON array-document. The backing storage of this type is opaque,
    /// permitting lazy parsing of its inline content.
    @frozen public
    struct Array<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        /// The raw data backing this array-document. This collection *does*
        /// include the trailing null byte that appears after its inline 
        /// elements list.
        public 
        let bytes:Bytes

        @inlinable public
        init(_ bytes:Bytes)
        {
            self.bytes = bytes
        }
    }
}
extension BSON.Array:Equatable where Bytes:Equatable
{
}
extension BSON.Array:Sendable where Bytes:Sendable
{
}
extension BSON.Array:TraversableBSON
{
    @inlinable public static
    var headerSize:Int
    {
        4
    }
    /// Stores the argument in ``bytes`` unchanged.
    ///
    /// >   Complexity: O(1)
    @inlinable public
    init(slicing bytes:Bytes)
    {
        self.init(bytes)
    }
}
extension BSON.Array
{
    /// The length that would be encoded in this array-document’s prefixed header.
    /// Equal to [`self.size`]().
    @inlinable public
    var header:Int32
    {
        .init(self.size)
    }

    /// The size of this array-document when encoded with its header.
    /// This *is* the same as the length encoded in the header itself.
    @inlinable public
    var size:Int
    {
        Self.headerSize + self.bytes.count
    }
}

extension BSON.Array
{
    /// Splits this array-document’s inline key-value pairs into an array containing the
    /// values only. Parsing an array-document is slightly faster than parsing a general 
    /// ``Document``, because this method ignores the document keys.
    ///
    /// This method does *not* perform any key validation.
    ///
    /// >   Complexity: O(*n*), where *n* is the size of this array-document’s backing storage.
    func parse() throws -> [BSON.Variant<Bytes.SubSequence>]
    {
        var input:BSON.Input<Bytes> = .init(self.bytes)
        var elements:[BSON.Variant<Bytes.SubSequence>] = []
        while let code:UInt8 = input.next()
        {
            if code != 0x00
            {
                try input.parse(through: 0x00)
                elements.append(try input.parse(variant: try .init(code: code)))
            }
            else
            {
                break
            }
        }
        try input.finish()
        return elements
    }
}
extension BSON.Array:ExpressibleByArrayLiteral 
    where Bytes:RangeReplaceableCollection<UInt8>
{
    @inlinable public 
    init(_ elements:some Sequence<BSON.Variant<some RandomAccessCollection<UInt8>>>)
    {
        // we do need to precompute the ordinal keys, so we know the total length
        // of the document.
        let document:BSON.Document<Bytes> = .init(elements.enumerated().map
        {
            ($0.0.description, $0.1)
        })
        self.init(document.bytes)
    }

    @inlinable public 
    init(arrayLiteral:BSON.Variant<Bytes>...)
    {
        self.init(arrayLiteral)
    }
}
extension BSON.Array where Bytes.SubSequence:Equatable
{
    @inlinable public static
    func =~= (lhs:Self, rhs:Self) -> Bool
    {
        BSON.Document<Bytes>.init(lhs) =~= BSON.Document<Bytes>.init(rhs)
    }
}
