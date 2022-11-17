import BSONDecoding
import NIOCore

extension Mongo
{
    @frozen public
    struct WriteConcern
    {
        public
        let acknowledgement:Acknowledgement
        public
        let journaled:Bool
        public
        let timeout:Duration?

        @inlinable public
        init(acknowledgement:Acknowledgement, journaled:Bool, timeout:Duration?)
        {
            self.acknowledgement = acknowledgement
            self.journaled = journaled
            self.timeout = timeout
        }
    }
}
extension Mongo.WriteConcern:MongoScheme, MongoRepresentable
{
    public
    init(bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self.init(acknowledgement: try bson["w"].decode
            {
                if case .string(let string) = $0
                {
                    let string:String = string.description
                    return string == "majority" ? .majority : .custom(string)
                }
                else
                {
                    return .count(try $0.as(Int.self))
                }
            },
            journaled: try bson["j"].decode(to: Bool.self),
            timeout: try bson["wtimeout"]?.decode(as: Int64.self,
                with: Duration.milliseconds(_:)))
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
extension Mongo.WriteConcern
{
    @frozen public
    enum Acknowledgement
    {
        case majority
        case count(Int)
        case custom(String)
    }
}
extension Mongo.WriteConcern.Acknowledgement
{
    var bson:BSON.Value<[UInt8]>
    {
        switch self
        {
        case .majority:
            return "majority"
        case .count(let instances):
            return .int64(Int64.init(instances))
        case .custom(let concern):
            return .string(concern)
        }
    }
}
