

extension BSON.Decoder:SingleValueDecodingContainer
{
    public 
    func decode<T>(_:T.Type) throws -> T where T:Decodable
    {
        try .init(from: self)
    }
    public
    func decodeNil() -> Bool
    {
        self.value.is(Void.self)
    }
    public
    func decode(_:Bool.Type) throws -> Bool
    {
        try self.diagnose { $0.as(Bool.self) }
    }
    public
    func decode(_:Float.Type) throws -> Float
    {
        try self.diagnose { $0.as(Float.self) }
    }
    public
    func decode(_:Double.Type) throws -> Double
    {
        try self.diagnose { $0.as(Double.self) }
    }
    public
    func decode(_:String.Type) throws -> String
    {
        try self.diagnose { $0.as(String.self) }
    }
    public
    func decode(_:Int.Type) throws -> Int
    {
        try self.diagnose { try $0.as(Int.self) }
    }
    public
    func decode(_:Int64.Type) throws -> Int64
    {
        try self.diagnose { try $0.as(Int64.self) }
    }
    public
    func decode(_:Int32.Type) throws -> Int32
    {
        try self.diagnose { try $0.as(Int32.self) }
    }
    public
    func decode(_:Int16.Type) throws -> Int16
    {
        try self.diagnose { try $0.as(Int16.self) }
    }
    public
    func decode(_:Int8.Type) throws -> Int8
    {
        try self.diagnose { try $0.as(Int8.self) }
    }
    public
    func decode(_:UInt.Type) throws -> UInt
    {
        try self.diagnose { try $0.as(UInt.self) }
    }
    public
    func decode(_:UInt64.Type) throws -> UInt64
    {
        try self.diagnose { try $0.as(UInt64.self) }
    }
    public
    func decode(_:UInt32.Type) throws -> UInt32
    {
        try self.diagnose { try $0.as(UInt32.self) }
    }
    public
    func decode(_:UInt16.Type) throws -> UInt16
    {
        try self.diagnose { try $0.as(UInt16.self) }
    }
    public
    func decode(_:UInt8.Type) throws -> UInt8
    {
        try self.diagnose { try $0.as(UInt8.self) }
    }
}

extension BSON.KeyedDecoder:KeyedDecodingContainerProtocol 
{
    public
    func decode<T>(_:T.Type, forKey key:Key) throws -> T where T:Decodable
    {
        return try .init(from: try self.singleValueContainer(forKey: key))
    }
    func decodeNil(forKey key:Key) throws -> Bool
    {
        try self.diagnose(key) { $0.is(Void.self) }
    }
    public
    func decode(_:Bool.Type, forKey key:Key) throws -> Bool
    {
        try self.diagnose(key) { $0.as(Bool.self) }
    }
    public
    func decode(_:Float.Type, forKey key:Key) throws -> Float
    {
        try self.diagnose(key) { $0.as(Float.self) }
    }
    public
    func decode(_:Double.Type, forKey key:Key) throws -> Double
    {
        try self.diagnose(key) { $0.as(Double.self) }
    }
    public
    func decode(_:String.Type, forKey key:Key) throws -> String
    {
        try self.diagnose(key) { $0.as(String.self) }
    }
    public
    func decode(_:Int.Type, forKey key:Key) throws -> Int
    {
        try self.diagnose(key) { try $0.as(Int.self) }
    }
    public
    func decode(_:Int64.Type, forKey key:Key) throws -> Int64
    {
        try self.diagnose(key) { try $0.as(Int64.self) }
    }
    public
    func decode(_:Int32.Type, forKey key:Key) throws -> Int32
    {
        try self.diagnose(key) { try $0.as(Int32.self) }
    }
    public
    func decode(_:Int16.Type, forKey key:Key) throws -> Int16
    {
        try self.diagnose(key) { try $0.as(Int16.self) }
    }
    public
    func decode(_:Int8.Type, forKey key:Key) throws -> Int8
    {
        try self.diagnose(key) { try $0.as(Int8.self) }
    }
    public
    func decode(_:UInt.Type, forKey key:Key) throws -> UInt
    {
        try self.diagnose(key) { try $0.as(UInt.self) }
    }
    public
    func decode(_:UInt64.Type, forKey key:Key) throws -> UInt64
    {
        try self.diagnose(key) { try $0.as(UInt64.self) }
    }
    public
    func decode(_:UInt32.Type, forKey key:Key) throws -> UInt32
    {
        try self.diagnose(key) { try $0.as(UInt32.self) }
    }
    public
    func decode(_:UInt16.Type, forKey key:Key) throws -> UInt16
    {
        try self.diagnose(key) { try $0.as(UInt16.self) }
    }
    public
    func decode(_:UInt8.Type, forKey key:Key) throws -> UInt8
    {
        try self.diagnose(key) { try $0.as(UInt8.self) }
    }
    
    func superDecoder() throws -> any Decoder
    {
        try self.singleValueContainer(forKey: BSON.ObjectKey.super, typed: BSON.ObjectKey.self)
    }
    public 
    func superDecoder(forKey key:Key) throws -> any Decoder
    {
        try self.singleValueContainer(forKey: key) as any Decoder
    }
    
    public 
    func singleValueContainer<Key>(forKey key:Key,
        typed _:Key.Type = Key.self) throws -> BSON.Decoder<Bytes>
        where Key:CodingKey
    {
        let value:BSON.Value<Bytes> = try self.diagnose(key){ $0 }
        let decoder:BSON.Decoder<Bytes> = .init(value, 
            path: self.codingPath + CollectionOfOne<any CodingKey>.init(key))
        return decoder
    }
    public 
    func nestedUnkeyedContainer(forKey key:Key) throws -> UnkeyedDecodingContainer
    {
        let path:[any CodingKey] = self.codingPath + CollectionOfOne<any CodingKey>.init(key)
        let container:BSON.UnkeyedDecoder<Bytes.SubSequence> =
            .init(try self.diagnose(key) { try $0.array() }, path: path)
        return container as UnkeyedDecodingContainer
    }
    public 
    func nestedContainer<NestedKey>(keyedBy _:NestedKey.Type,
        forKey key:Key) throws -> KeyedDecodingContainer<NestedKey>
    {
        let path:[any CodingKey] = self.codingPath + CollectionOfOne<any CodingKey>.init(key)
        let container:BSON.KeyedDecoder<Bytes.SubSequence, NestedKey> =
            .init(try self.diagnose(key) { try $0.dictionary() }, path: path)
        return .init(container)
    }
}

extension BSON.UnkeyedDecoder:UnkeyedDecodingContainer
{
    public mutating 
    func decode<T>(_:T.Type) throws -> T where T:Decodable
    {
        try .init(from: try self.singleValueContainer())
    }
    public mutating 
    func decodeNil() throws -> Bool
    {
        try self.diagnose { $0.is(Void.self) }
    }
    public mutating 
    func decode(_:Bool.Type) throws -> Bool
    {
        try self.diagnose { $0.as(Bool.self) }
    }
    public mutating 
    func decode(_:Float.Type) throws -> Float
    {
        try self.diagnose { $0.as(Float.self) }
    }
    public mutating 
    func decode(_:Double.Type) throws -> Double
    {
        try self.diagnose { $0.as(Double.self) }
    }
    public mutating 
    func decode(_:String.Type) throws -> String
    {
        try self.diagnose { $0.as(String.self) }
    }
    public mutating 
    func decode(_:Int.Type) throws -> Int
    {
        try self.diagnose { try $0.as(Int.self) }
    }
    public mutating 
    func decode(_:Int64.Type) throws -> Int64
    {
        try self.diagnose { try $0.as(Int64.self) }
    }
    public mutating 
    func decode(_:Int32.Type) throws -> Int32
    {
        try self.diagnose { try $0.as(Int32.self) }
    }
    public mutating 
    func decode(_:Int16.Type) throws -> Int16
    {
        try self.diagnose { try $0.as(Int16.self) }
    }
    public mutating 
    func decode(_:Int8.Type) throws -> Int8
    {
        try self.diagnose { try $0.as(Int8.self) }
    }
    public mutating 
    func decode(_:UInt.Type) throws -> UInt
    {
        try self.diagnose { try $0.as(UInt.self) }
    }
    public mutating 
    func decode(_:UInt64.Type) throws -> UInt64
    {
        try self.diagnose { try $0.as(UInt64.self) }
    }
    public mutating 
    func decode(_:UInt32.Type) throws -> UInt32
    {
        try self.diagnose { try $0.as(UInt32.self) }
    }
    public mutating 
    func decode(_:UInt16.Type) throws -> UInt16
    {
        try self.diagnose { try $0.as(UInt16.self) }
    }
    public mutating 
    func decode(_:UInt8.Type) throws -> UInt8
    {
        try self.diagnose { try $0.as(UInt8.self) }
    }
    
    public mutating  
    func superDecoder() throws -> any Decoder
    {
        try self.singleValueContainer() as any Decoder
    }
    public mutating 
    func singleValueContainer() throws -> BSON.Decoder<Bytes>
    {
        let key:BSON.TupleKey = .init(intValue: self.currentIndex) 
        let value:BSON.Value<Bytes> = try self.diagnose { $0 }
        let decoder:BSON.Decoder<Bytes> = .init(value, 
            path: self.codingPath + CollectionOfOne<any CodingKey>.init(key))
        return decoder
    }
    public mutating 
    func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer
    {
        let path:[any CodingKey] = self.codingPath +
            CollectionOfOne<any CodingKey>.init(BSON.TupleKey.init(intValue: self.currentIndex))
        let container:BSON.UnkeyedDecoder<Bytes.SubSequence> =
            .init(try self.diagnose { try $0.array() }, path: path)
        return container as any UnkeyedDecodingContainer
    }
    public mutating 
    func nestedContainer<NestedKey>(keyedBy _:NestedKey.Type) 
        throws -> KeyedDecodingContainer<NestedKey>
    {
        let path:[any CodingKey] = self.codingPath + 
            CollectionOfOne<any CodingKey>.init(BSON.TupleKey.init(intValue: self.currentIndex))
        let container:BSON.KeyedDecoder<Bytes.SubSequence, NestedKey> = 
            .init(try self.diagnose { try $0.dictionary() }, path: path)
        return .init(container)
    }
}
