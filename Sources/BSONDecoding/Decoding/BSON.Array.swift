extension BSON
{
    /// A document had an invalid key schema.
    @frozen public
    struct ArrayShapeError:Equatable, Error
    {
        public
        let count:Int
        public
        let expected:Int?

        @inlinable public
        init(count:Int, expected:Int? = nil)
        {
            self.count = count
            self.expected = expected
        }
    }
}
extension BSON.ArrayShapeError
{
    /// Returns the string [`"shape error"`]().
    public static 
    var namespace:String 
    {
        "shape error"
    }
    public
    var message:String
    {
        if let expected:Int = self.expected
        {
            return "invalid element count (\(self.count)), expected \(expected) elements"
        }
        else
        {
            return "invalid element count (\(self.count))"
        }
    }
}

extension BSON
{
    /// A thin wrapper around a native Swift array providing an efficient decoding
    /// interface for a ``BSON/Tuple``.
    @frozen public
    struct Array<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        public
        var elements:[BSON.Value<Bytes>]

        @inlinable public
        init(_ elements:[BSON.Value<Bytes>])
        {
            self.elements = elements
        }
    }
}

extension BSON.Array:RandomAccessCollection
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
    subscript(index:Int) -> BSON.ExplicitField<Int, Bytes>
    {
        .init(key: index, value: self.elements[index])
    }
}
