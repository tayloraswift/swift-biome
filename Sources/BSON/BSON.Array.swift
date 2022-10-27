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
    }
}
extension BSON.Array:TraversableBSON
{
    @inlinable public static
    var headerBytes:Int
    {
        4
    }
    @inlinable public
    init(_ bytes:Bytes)
    {
        self.bytes = bytes
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
        var input:BSON.ParsingInput<Bytes> = .init(self.bytes)
        var elements:[BSON.Variant<Bytes.SubSequence>] = []
        while let variant:UInt8 = input.next()
        {
            if  variant != 0x00
            {
                try input.parse(through: 0x00)
                elements.append(try input.parse(variant: variant))
            }
            else
            {
                break
            }
        }
        if input.index == input.source.endIndex
        {
            return elements
        }
        else
        {
            throw BSON.ParsingError.trailed(
                bytes: input.source.distance(from: input.index, to: input.source.endIndex))
        }
    }
}
