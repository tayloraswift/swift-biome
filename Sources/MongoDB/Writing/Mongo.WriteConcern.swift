import BSONSchema

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
extension Mongo.WriteConcern:BSONDocumentEncodable
{
    public
    func encode(to bson:inout BSON.Fields)
    {
        bson["w"] = self.acknowledgement
        bson["j"] = self.journaled
        bson["wtimeout"] = self.timeout
    }
}
extension Mongo.WriteConcern:BSONDictionaryDecodable
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
