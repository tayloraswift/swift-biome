import BSONDecoding
import BSONEncoding

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
        let timeout:Milliseconds?

        @inlinable public
        init(acknowledgement:WriteAcknowledgement, journaled:Bool, timeout:Milliseconds?)
        {
            self.acknowledgement = acknowledgement
            self.journaled = journaled
            self.timeout = timeout
        }
    }
}
extension Mongo.WriteConcern:MongoDecodable, BSONDictionaryDecodable
{
    @inlinable public
    init(bson:BSON.Dictionary<some RandomAccessCollection<UInt8>>) throws
    {
        self.init(
            acknowledgement: try bson["w"].decode(to: Mongo.WriteAcknowledgement.self),
            journaled: try bson["j"].decode(to: Bool.self),
            timeout: try bson["wtimeout"]?.decode(to: Mongo.Milliseconds.self))
    }
}
extension Mongo.WriteConcern:MongoEncodable
{
    public
    var document:Mongo.Document
    {
        [
            "w": self.acknowledgement.bson,
            "j": .bool(self.journaled),
            "wtimeout": .int64(self.timeout?.rawValue),
        ]
    }
}
