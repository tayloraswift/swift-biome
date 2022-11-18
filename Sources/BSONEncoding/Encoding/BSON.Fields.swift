extension BSON
{
    @frozen public
    struct Fields<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        public
        var elements:[(key:String, value:BSON.Value<Bytes>)]

        @inlinable public
        init(_ elements:[(key:String, value:BSON.Value<Bytes>)])
        {
            self.elements = elements
        }
    }
}
extension BSON.Fields:Sendable where Bytes:Sendable, Bytes.SubSequence:Sendable
{
}
extension BSON.Fields:RandomAccessCollection, MutableCollection
{
    @inlinable public
    var startIndex:Int
    {
        self.elements.startIndex
    }
    @inlinable public
    var endIndex:Int
    {
        self.elements.endIndex
    }
    @inlinable public
    subscript(index:Int) -> (key:String, value:BSON.Value<Bytes>)
    {
        _read
        {
            yield  self.elements[index]
        }
        _modify
        {
            yield &self.elements[index]
        }
    }
}
extension BSON.Fields
{
    @inlinable public mutating
    func add(key:String, value:BSON.Value<Bytes>)
    {
        self.elements.append((key, value))
    }
}
extension BSON.Fields:ExpressibleByDictionaryLiteral
{
    @inlinable public
    init(dictionaryLiteral:(String, BSON.Value<Bytes>?)...)
    {
        self.init(dictionaryLiteral.compactMap
        { 
            (item:(key:String, value:BSON.Value<Bytes>?)) in item.value.map { (item.key, $0) }
        })
    }
}
