import BSONDecoding

extension Mongo
{
    @frozen public
    struct StorageConfiguration
    {
        @usableFromInline
        var engines:[(name:String, options:Document)]

        @inlinable public
        init(_ engines:[(name:String, options:Document)])
        {
            self.engines = engines
        }
    }
}
extension Mongo.StorageConfiguration:MongoEncodable
{
    public
    var document:Mongo.Document
    {
        .init(self.engines.lazy.map { ($0.name, .document($0.options.bson)) })
    }
}
extension Mongo.StorageConfiguration:MongoDecodable
{
    @inlinable public
    init<Bytes>(bson:BSON.Document<Bytes>) throws
    {
        self.init(try bson.parse().map
        {
            let field:BSON.ExplicitField<String, Bytes.SubSequence> = .init(key: $0.0,
                value: $0.1)
            return ($0.0, try field.decode(to: Mongo.Document.self))
        })
    }
}
extension Mongo.StorageConfiguration:ExpressibleByDictionaryLiteral
{
    @inlinable public
    init(dictionaryLiteral:(String, Mongo.Document)...)
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
    subscript(index:Int) -> (name:String, options:Mongo.Document)
    {
        self.engines[index]
    }
}
