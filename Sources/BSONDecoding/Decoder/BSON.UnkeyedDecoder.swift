extension BSON
{
    struct UnkeyedDecoder<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        public 
        let codingPath:[any CodingKey]
        public 
        var currentIndex:Int 
        let elements:[BSON.Value<Bytes>]
        
        public 
        init(_ array:BSON.Array<Bytes>, path:[any CodingKey])
        {
            self.codingPath     = path
            self.elements       = array.elements
            self.currentIndex   = self.elements.startIndex 
        }
    }
}
extension BSON.UnkeyedDecoder
{
    public 
    var count:Int?
    {
        self.elements.count
    }
    public 
    var isAtEnd:Bool 
    {
        self.currentIndex >= self.elements.endIndex
    }
    
    mutating 
    func diagnose<T>(_ decode:(BSON.Value<Bytes>) throws -> T?) throws -> T
    {
        let key:BSON.TupleKey = .init(intValue: self.currentIndex) 
        var path:[any CodingKey] 
        { 
            self.codingPath + CollectionOfOne<any CodingKey>.init(key) 
        }
        
        if self.isAtEnd 
        {
            let context:DecodingError.Context = .init(codingPath: path, 
                debugDescription: "index (\(self.currentIndex)) out of range")
            throw DecodingError.keyNotFound(key, context)
        }
        
        let value:BSON.Value<Bytes> = self.elements[self.currentIndex]
        self.currentIndex += 1
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
