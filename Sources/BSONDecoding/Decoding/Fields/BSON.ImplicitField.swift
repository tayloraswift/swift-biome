extension BSON
{
    /// A field that may or may not exist in a document. This type is
    /// the return value of ``Dictionary``’s non-optional subscript, and
    /// is useful for obtaining structured diagnostics for “key-not-found”
    /// scenarios.
    @frozen public
    struct ImplicitField<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        public
        let key:String
        public
        let value:BSON.Value<Bytes>?

        @inlinable public
        init(key:String, value:BSON.Value<Bytes>?)
        {
            self.key = key
            self.value = value
        }
    }
}
extension BSON.ImplicitField
{
    @inlinable public static
    func ?? (lhs:Self, rhs:@autoclosure () -> Self) -> Self
    {
        if case nil = lhs.value
        {
            return rhs()
        }
        else
        {
            return lhs
        }
    }
}
extension BSON.ImplicitField
{
    /// Gets the value of this key, throwing a ``BSON/DictionaryKeyError``
    /// if it is [`nil`](). This is a distinct condition from an explicit
    /// ``BSON.null`` value, which will be returned without throwing an error.
    @inlinable public
    func decode() throws -> BSON.Value<Bytes>
    {
        if let value:BSON.Value<Bytes> = self.value
        {
            return value 
        }
        else 
        {
            throw BSON.DictionaryKeyError.undefined(self.key)
        }
    }
}
extension BSON.ImplicitField:DecoderField
{
    /// Decodes the value of this implicit field with the given decoder, throwing a
    /// ``BSON/DictionaryKeyError`` if it does not exist. Throws a
    /// ``BSON/RecursiveError.document(_:in:)`` wrapping the underlying error if
    /// decoding fails.
    @inlinable public
    func decode<T>(with decode:(BSON.Value<Bytes>) throws -> T) throws -> T
    {
        // we cannot *quite* shove this into the `do` block, because we 
        // do not want to throw a ``RecursiveError`` just because the key 
        // was not found.
        let value:BSON.Value<Bytes> = try self.decode()
        do 
        {
            return try decode(value)
        }
        catch let error 
        {
            throw BSON.RecursiveError.init(error, in: key)
        }
    }
}
