import BSONDecoding
import BSONEncoding
import NIOCore

extension Mongo
{
    @frozen public
    struct WriteConcern:Hashable, Sendable
    {
        public
        let acknowledgement:WriteAcknowledgement
        public
        let journaled:Bool
        public
        let timeout:Duration?

        @inlinable public
        init(acknowledgement:WriteAcknowledgement, journaled:Bool, timeout:Duration?)
        {
            self.acknowledgement = acknowledgement
            self.journaled = journaled
            self.timeout = timeout
        }
    }
}
extension Mongo.WriteConcern:MongoScheme
{
    public
    init(bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self.init(
            acknowledgement: try bson["w"].decode(
                with: Mongo.WriteAcknowledgement.init(bson:)),
            journaled: try bson["j"].decode(to: Bool.self),
            timeout: try bson["wtimeout"]?.decode(as: Int64.self,
                with: Mongo.Duration.init(milliseconds:)))
    }
    public
    var bson:BSON.Document<[UInt8]>
    {
        let fields:BSON.Fields<[UInt8]> =
        [
            "w": self.acknowledgement.bson,
            "j": .bool(self.journaled),
            "wtimeout": .int64(self.timeout?.milliseconds),
        ]
        return .init(fields)
    }
}
