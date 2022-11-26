import BSONSchema

extension Mongo
{
    @frozen public
    struct StorageConfiguration:Sendable
    {
        @usableFromInline
        var engines:[(name:String, options:BSON.Fields)]

        @inlinable public
        init(_ engines:[(name:String, options:BSON.Fields)])
        {
            self.engines = engines
        }
    }
}
extension Mongo.StorageConfiguration:BSONDocumentEncodable
{
    public
    func encode(to bson:inout BSON.Fields)
    {
        bson = .init(self.engines.lazy.map { ($0.name, $0.options.bson) })
    }
}
extension Mongo.StorageConfiguration:BSONDocumentDecodable
{
    @inlinable public
    init<Bytes>(bson:BSON.Document<Bytes>) throws
    {
        self.init(try bson.parse().map
        {
            let field:BSON.ExplicitField<String, Bytes.SubSequence> = .init(key: $0.0,
                value: $0.1)
            return ($0.0, try field.decode(to: BSON.Fields.self))
        })
    }
}
extension Mongo.StorageConfiguration:ExpressibleByDictionaryLiteral
{
    @inlinable public
    init(dictionaryLiteral:(String, BSON.Fields)...)
    {
        self.init(dictionaryLiteral)
    }
}
extension Mongo.StorageConfiguration:RandomAccessCollection
{
    @inlinable public
    var startIndex:Int
    {
        self.engines.startIndex
    }
    @inlinable public
    var endIndex:Int
    {
        self.engines.endIndex
    }
    @inlinable public
    subscript(index:Int) -> (name:String, options:BSON.Fields)
    {
        self.engines[index]
    }
}
