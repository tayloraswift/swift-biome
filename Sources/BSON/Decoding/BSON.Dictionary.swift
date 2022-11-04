extension BSON
{
    /// A document had an invalid key schema.
    @frozen public
    enum DictionaryKeyError:Error
    {
        /// A document contained more than one field with the same key.
        case duplicate(String)
        /// A document did not contain a field with the expected key.
        case undefined(String, keys:[String])
    }
}
extension BSON.DictionaryKeyError
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
        switch self
        {
        case .duplicate(let key):
            return "duplicate key '\(key)'"
        case .undefined(let key, keys: let keys):
            return "undefined key '\(key)'; valid keys are: \(keys)"
        }
    }
}

extension BSON
{
    /// A thin wrapper around a native Swift dictionary providing an efficient decoding
    /// interface for a ``BSON/Document``.
    @frozen public
    struct Dictionary<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        public
        var items:[String: BSON.Variant<Bytes>]
        
        @inlinable public
        init(_ items:[String: BSON.Variant<Bytes>])
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
    init(fields:[(key:String, value:BSON.Variant<Bytes>)]) throws
    {
        self.items = .init(minimumCapacity: fields.count)
        for (key, value):(String, BSON.Variant<Bytes>) in fields
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
    /// Gets the field value for the specified key, throwing a ``BSON/DictionaryKeyError``
    /// if it does not exist.
    @inlinable public
    func decode(_ key:String) throws -> BSON.Variant<Bytes>
    {
        if let value:BSON.Variant<Bytes> = self.items[key]
        {
            return value 
        }
        else 
        {
            throw BSON.DictionaryKeyError.undefined(key, keys: .init(self.items.keys))
        }
    }
    /// Decodes the field value for the specified key with the given decoder, throwing a
    /// ``BSON/DictionaryKeyError`` if it does not exist. Throws a
    /// ``BSON/RecursiveError.document(_:in:)`` wrapping the underlying error if decoding
    /// fails.
    @inlinable public
    func decode<T>(_ key:String,
        with decode:(BSON.Variant<Bytes>) throws -> T) throws -> T
    {
        // we cannot *quite* shove this into the `do` block, because we 
        // do not want to throw a ``RecursiveError`` just because the key 
        // was not found.
        let value:BSON.Variant<Bytes> = try self.decode(key)
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
    func decode<T>(mapping key:String,
        with decode:(BSON.Variant<Bytes>) throws -> T) rethrows -> T?
    {
        do 
        {
            return try self.items[key].map(decode)
        }
        catch let error 
        {
            throw BSON.RecursiveError.document(error, in: key)
        }
    }
}
