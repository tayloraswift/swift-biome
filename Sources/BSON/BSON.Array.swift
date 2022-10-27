import BSONTraversal

extension BSON
{
    @frozen public
    struct Array<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
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
