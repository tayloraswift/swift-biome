import BSONDecoding
import NIOCore

extension Mongo.KillCursors
{
    public
    struct Response
    {
        public
        let alive:[Int64]
        public
        let killed:[Int64]
        public
        let notFound:[Int64]
        public
        let unknown:[Int64]

        public
        init(alive:[Int64],
            killed:[Int64],
            notFound:[Int64],
            unknown:[Int64])
        {
            self.alive = alive
            self.killed = killed
            self.notFound = notFound
            self.unknown = unknown
        }
    }
}
extension Mongo.KillCursors.Response:MongoDecodable
{
    @inlinable public
    init(bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self.init(
            alive: try bson["cursorsAlive"].decode(as: BSON.Array<ByteBufferView>.self)
            {
                try $0.map { try $0.decode(to: Int64.self) }
            },
            killed: try bson["cursorsKilled"].decode(as: BSON.Array<ByteBufferView>.self)
            {
                try $0.map { try $0.decode(to: Int64.self) }
            },
            notFound: try bson["cursorsNotFound"].decode(as: BSON.Array<ByteBufferView>.self)
            {
                try $0.map { try $0.decode(to: Int64.self) }
            },
            unknown: try bson["cursorsUnknown"].decode(as: BSON.Array<ByteBufferView>.self)
            {
                try $0.map { try $0.decode(to: Int64.self) }
            })
    }
}
