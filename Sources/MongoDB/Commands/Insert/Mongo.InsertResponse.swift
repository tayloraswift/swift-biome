import BSONDecoding

extension Mongo
{
    public
    struct InsertResponse:Equatable, Sendable
    {
        public
        let writeConcernErrors:[WriteConcernError]
        public
        let writeErrors:[WriteError]
        public
        let inserted:Int

        public
        init(inserted:Int,
            writeConcernErrors:[WriteConcernError] = [],
            writeErrors:[WriteError] = [])
        {
            self.writeConcernErrors = writeConcernErrors
            self.writeErrors = writeErrors
            self.inserted = inserted
        }
    }
}
extension Mongo.InsertResponse:BSONDictionaryDecodable
{
    @inlinable public
    init<Bytes>(bson:BSON.Dictionary<Bytes>) throws
    {
        self.init(inserted: try bson["n"].decode(to: Int.self),
            writeConcernErrors: try bson["writeConcernErrors"]?.decode(
                to: [Mongo.WriteConcernError].self) ?? [],
            writeErrors: try bson["writeErrors"]?.decode(
                to: [Mongo.WriteError].self) ?? [])
    }
}
