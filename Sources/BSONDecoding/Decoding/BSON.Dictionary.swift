extension BSON
{
    /// A thin wrapper around a native Swift dictionary providing an efficient decoding
    /// interface for a ``BSON/Document``.
    @frozen public
    struct Dictionary<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        public
        var items:[String: BSON.Value<Bytes>]
        
        @inlinable public
        init(_ items:[String: BSON.Value<Bytes>])
        {
            self.items = items
        }
    }
}
extension BSON.Dictionary
{
    /// Creates a dictionary-decoder from a list of document fields, throwing a
    /// ``DictionaryKeyError`` if more than one document field contains a key with
    /// the same name.
    @inlinable public
    init(fields:[(key:String, value:BSON.Value<Bytes>)]) throws
    {
        self.items = .init(minimumCapacity: fields.count)
        for (key, value):(String, BSON.Value<Bytes>) in fields
        {
            if case _? = self.items.updateValue(value, forKey: key)
            {
                throw BSON.DictionaryKeyError.duplicate(key)
            }
        }
    }
}
extension BSON.Dictionary
{
    @inlinable public
    subscript(key:String) -> BSON.ExplicitField<String, Bytes>?
    {
        self.items[key].map { .init(key: key, value: $0) }
    }
    @inlinable public
    subscript(key:String) -> BSON.ImplicitField<Bytes>
    {
        .init(key: key, value: self.items[key])
    }
}
