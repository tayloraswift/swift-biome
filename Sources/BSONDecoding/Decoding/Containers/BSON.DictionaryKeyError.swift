extension BSON
{
    /// A document had an invalid key schema.
    @frozen public
    enum DictionaryKeyError:Equatable, Error
    {
        /// A document contained more than one field with the same key.
        case duplicate(String)
        /// A document did not contain a field with the expected key.
        case undefined(String)
    }
}
extension BSON.DictionaryKeyError:CustomStringConvertible
{
    public
    var description:String
    {
        switch self
        {
        case .duplicate(let key):
            return "duplicate key '\(key)'"
        case .undefined(let key):
            return "undefined key '\(key)'"
        }
    }
}
