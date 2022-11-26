import BSONSchema

extension Mongo
{
    @frozen public
    struct ReadConcern:Hashable, Sendable
    {
        public
        let level:Level

        @inlinable public
        init(level:Level)
        {
            self.level = level
        }
    }
}
extension Mongo.ReadConcern:BSONDocumentEncodable
{
    public
    func encode(to bson:inout BSON.Fields)
    {
        bson["level"] = self.level
    }
}
extension Mongo.ReadConcern:BSONDictionaryDecodable
{
    @inlinable public
    init(bson:BSON.Dictionary<some RandomAccessCollection<UInt8>>) throws
    {
        self.init(level: try bson["level"].decode(to: Level.self))
    }
}
