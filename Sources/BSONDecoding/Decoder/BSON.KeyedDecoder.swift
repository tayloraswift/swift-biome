extension BSON
{
    struct KeyedDecoder<Bytes, Key> where Bytes:RandomAccessCollection<UInt8>, Key:CodingKey
    {
        let codingPath:[any CodingKey]
        let allKeys:[Key]
        let items:[String: BSON.Value<Bytes>]
        
        init(_ dictionary:BSON.Dictionary<Bytes>, path:[any CodingKey]) 
        {
            self.codingPath = path
            self.items = dictionary.items
            self.allKeys = self.items.keys.compactMap(Key.init(stringValue:))
        }
    }
}
extension BSON.KeyedDecoder
{
    public
    func contains(_ key:Key) -> Bool 
    {
        self.items.keys.contains(key.stringValue)
    }
    // local `Key` type may be different from the dictionary’s `Key` type
    func diagnose<T>(_ key:some CodingKey,
        _ decode:(BSON.Value<Bytes>) throws -> T?) throws -> T
    {
        var path:[any CodingKey]
        { 
            self.codingPath + CollectionOfOne<any CodingKey>.init(key) 
        }
        guard let value:BSON.Value<Bytes> = self.items[key.stringValue]
        else 
        {
            let context:DecodingError.Context = .init(codingPath: path, 
                debugDescription: "key '\(key)' not found")
            throw DecodingError.keyNotFound(key, context)
        }
        do 
        {
            if let decoded:T = try decode(value)
            {
                return decoded
            }

            throw DecodingError.init(annotating: BSON.TypecastError<T>.init(
                    invalid: value.type),
                initializing: T.self,
                path: path)
        }
        catch let error
        {
            throw DecodingError.init(annotating: error,
                initializing: T.self,
                path: path)
        }
    }
}
