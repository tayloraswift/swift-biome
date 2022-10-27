import BSONTraversal

extension BSON
{
    @frozen public
    struct UTF8<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        public 
        let bytes:Bytes.SubSequence
    }
}
extension BSON.UTF8:CustomStringConvertible
{
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
