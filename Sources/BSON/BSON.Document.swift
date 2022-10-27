import BSONTraversal

extension BSON
{
    @frozen public
    struct Document<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
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
}

extension BSON.Document
{
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
