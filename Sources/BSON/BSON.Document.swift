import BSONTraversal

extension BSON
{
    /// A BSON document. The backing storage of this type is opaque,
    /// permitting lazy parsing of its inline content.
    @frozen public
    struct Document<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        /// The raw data backing this document. This collection *does*
        /// include the trailing null byte that appears after its inline 
        /// elements list.
        public 
        let bytes:Bytes
    }
}
extension BSON.Document:TraversableBSON
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
    /// Upcasts a BSON array to a document.
    ///
    /// >   Complexity: O(1)
    @inlinable public
    init(_ array:BSON.Array<Bytes>)
    {
        self.bytes = array.bytes
    }
}

extension BSON.Document
{
    /// Splits this document’s inline key-value pairs into an array.
    ///
    /// >   Complexity: O(*n*), where *n* is the size of this document’s backing storage.
    func parse() throws -> [(key:String, value:BSON.Variant<Bytes.SubSequence>)]
    {
        var input:BSON.ParsingInput<Bytes> = .init(self.bytes)
        var items:[(key:String, value:BSON.Variant<Bytes.SubSequence>)] = []
        while let variant:UInt8 = input.next()
        {
            if  variant != 0x00
            {
                let key:String = try input.parse(as: String.self)
                items.append((key, try input.parse(variant: variant)))
            }
            else
            {
                break
            }

        }
        if input.index == input.source.endIndex
        {
            return items
        }
        else
        {
            throw BSON.ParsingError.trailed(
                bytes: input.source.distance(from: input.index, to: input.source.endIndex))
        }
    }
}
