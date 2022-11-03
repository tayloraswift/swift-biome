extension BSON
{
    /// A document did not contain a field with the expected key.
    public
    struct KeyError:Error
    {
        public
        let undefined:String
        public
        let keys:[String]

        public
        init(_ undefined:String, keys:[String])
        {
            self.undefined = undefined
            self.keys = keys
        }
    }
}
extension BSON.KeyError
{
    /// Returns the string [`"key error"`]().
    public static 
    var namespace:String 
    {
        "key error"
    }
    public
    var message:String
    {
        "undefined key '\(self.undefined)'; valid keys are: \(self.keys)"
    }
}

extension Dictionary where Key == String
{
    /// Gets the field value for the specified key, throwing a ``BSON/KeyError`` if it
    /// does not exist.
    @inlinable public
    func decode<Bytes>(_ key:String) throws -> Value
        where Value == BSON.Variant<Bytes>
    {
        if let value:Value = self[key]
        {
            return value 
        }
        else 
        {
            throw BSON.KeyError.init(key, keys: .init(self.keys))
        }
    }
    /// Decodes the field value for the specified key with the given decoder, throwing a
    /// ``BSON/KeyError`` if it does not exist. Throws a
    /// ``BSON/RecursiveError.document(_:in:)`` wrapping the underlying error if decoding
    /// fails.
    @inlinable public
    func decode<Bytes, T>(_ key:String, with decode:(Value) throws -> T) throws -> T
        where Value == BSON.Variant<Bytes>
    {
        // we cannot *quite* shove this into the `do` block, because we 
        // do not want to throw a ``RecursiveError`` just because the key 
        // was not found.
        let value:Value = try self.decode(key)
        do 
        {
            return try decode(value)
        }
        catch let error 
        {
            throw BSON.RecursiveError.document(error, in: key)
        }
    }
    /// Decodes the field value for the specified key with the given decoder, if it exists.
    /// Throws a ``BSON/RecursiveError.document(_:in:)`` wrapping the underlying error
    /// if decoding fails.
    ///
    /// -   Returns: The return value of the given decoder, or [`nil`]()
    ///     if `key` is not present in this dictionary.
    @inlinable public
    func decode<Bytes, T>(mapping key:String, with decode:(Value) throws -> T) rethrows -> T?
        where Value == BSON.Variant<Bytes>
    {
        do 
        {
            return try self[key].map(decode)
        }
        catch let error 
        {
            throw BSON.RecursiveError.document(error, in: key)
        }
    }
}
