import BSONDecoding
import BSONEncoding

extension Mongo
{
    @frozen public
    struct Timeseries:Sendable
    {
        public
        let timeField:String
        public
        let metaField:String?
        public
        let granularity:Granularity

        @inlinable public
        init(timeField:String, metaField:String? = nil, granularity:Granularity = .seconds)
        {
            self.timeField = timeField
            self.metaField = metaField
            self.granularity = granularity
        }
    }
}
extension Mongo.Timeseries:MongoDecodable, BSONDictionaryDecodable
{
    @inlinable public
    init(bson:BSON.Dictionary<some RandomAccessCollection<UInt8>>) throws
    {
        self.init(
            timeField: try bson["timeField"].decode(to: String.self),
            metaField: try bson["metaField"]?.decode(to: String.self),
            granularity: try bson["granularity"].decode(to: Granularity.self))
    }
}
extension Mongo.Timeseries:MongoEncodable
{
    public
    var document:Mongo.Document
    {
        [
            "timeField": .string(self.timeField),
            "metaField": .string(self.metaField),
            "granularity": .string(self.granularity.rawValue),
        ]
    }
}
