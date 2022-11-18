import BSONDecoding
import NIOCore

extension Mongo
{
    @frozen public
    struct WriteConcernError:Equatable, Error, Sendable
    {
        public
        let message:String
        public
        let code:Int32

        public
        let writeConcernProvenance:WriteConcernProvenance
        public
        let writeConcern:WriteConcern

        @inlinable public
        init(message:String, code:Int32,
            writeConcernProvenance:WriteConcernProvenance,
            writeConcern:WriteConcern)
        {
            self.message = message
            self.code = code

            self.writeConcernProvenance = writeConcernProvenance
            self.writeConcern = writeConcern
        }
    }
}
extension Mongo.WriteConcernError:MongoDecodable
{
    public
    init(bson:BSON.Dictionary<ByteBufferView>) throws
    {
        let (writeConcern, writeConcernProvenance):
        (
            Mongo.WriteConcern,
            Mongo.WriteConcernProvenance
        ) = try bson["errInfo"].decode(as: BSON.Dictionary<ByteBufferView>.self)
        {
            try $0["writeConcern"].decode(as: BSON.Dictionary<ByteBufferView>.self)
            {
                (
                    try .init(bson: $0),
                    try $0["provenance"].decode(cases: Mongo.WriteConcernProvenance.self)
                )
            }
        }
        self.init(message: try bson["errmsg"].decode(to: String.self),
            code: try bson["code"].decode(to: Int32.self),
            writeConcernProvenance: writeConcernProvenance,
            writeConcern: writeConcern)
    }
}
