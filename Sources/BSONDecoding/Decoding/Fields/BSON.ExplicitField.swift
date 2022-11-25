extension BSON
{
    @frozen public
    struct ExplicitField<Key, Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        public
        let key:Key
        public
        let value:BSON.Value<Bytes>

        @inlinable public
        init(key:Key, value:BSON.Value<Bytes>)
        {
            self.key = key
            self.value = value
        }
    }
}
extension BSON.ExplicitField:DecoderField
{
    /// Decodes the value of this field with the given decoder.
    /// Throws a ``BSON/RecursiveError`` wrapping the underlying
    /// error if decoding fails.
    @inlinable public
    func decode<T>(with decode:(BSON.Value<Bytes>) throws -> T) throws -> T
    {
        do
        {
            return try decode(self.value)
        }
        catch let error 
        {
            throw BSON.RecursiveError.init(error, in: self.key)
        }
    }
}
