import BSONDecoding

extension Mongo.KillCursors
{
    public
    struct Response:Sendable
    {
        public
        let alive:[Mongo.CursorIdentifier]
        public
        let killed:[Mongo.CursorIdentifier]
        public
        let notFound:[Mongo.CursorIdentifier]
        public
        let unknown:[Mongo.CursorIdentifier]

        public
        init(alive:[Mongo.CursorIdentifier],
            killed:[Mongo.CursorIdentifier],
            notFound:[Mongo.CursorIdentifier],
            unknown:[Mongo.CursorIdentifier])
        {
            self.alive = alive
            self.killed = killed
            self.notFound = notFound
            self.unknown = unknown
        }
    }
}
extension Mongo.KillCursors.Response:BSONDictionaryDecodable
{
    @inlinable public
    init(bson:BSON.Dictionary<some RandomAccessCollection<UInt8>>) throws
    {
        self.init(
            alive: try bson["cursorsAlive"].decode(to: [Mongo.CursorIdentifier].self),
            killed: try bson["cursorsKilled"].decode(to: [Mongo.CursorIdentifier].self),
            notFound: try bson["cursorsNotFound"].decode(to: [Mongo.CursorIdentifier].self),
            unknown: try bson["cursorsUnknown"].decode(to: [Mongo.CursorIdentifier].self))
    }
}
