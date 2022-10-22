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
    var bson:Document
    {
        [
            "w": self.acknowledgement.bson,
            "j": self.journaled,
            "wtimeout": Int.init(self.timeout.milliseconds),
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
    var bson:any Primitive
    {
        switch self
        {
        case .majority:
            return "majority"
        case .count(let instances):
            return instances
        case .custom(let concern):
            return concern
        }
    }
}
