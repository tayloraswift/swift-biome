import BSON

extension Duration
{
    var milliseconds:Int64
    {
        self.components.seconds     * 1_000 +
        self.components.attoseconds / 1_000_000_000_000_000
    }
}

extension Mongo
{
    @frozen public
    struct WriteConcern
    {
        let acknowledgement:Acknowledgement
        let journaled:Bool
        let timeout:Duration
    }
}
extension Mongo.WriteConcern
{
    var bson:BSON.Document<[UInt8]>
    {
        [
            "w": self.acknowledgement.bson,
            "j": .bool(self.journaled),
            "wtimeout": .int64(self.timeout.milliseconds),
        ]
    }

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
