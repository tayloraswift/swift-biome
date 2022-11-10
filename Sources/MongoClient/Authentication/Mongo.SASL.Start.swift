import BSONEncoding

extension Mongo.SASL
{
    struct Start
    {
        let mechanism:Mechanism
        let payload:String
    }
}
extension Mongo.SASL.Start:MongoAuthenticationCommand
{
    var fields:BSON.Fields<[UInt8]>
    {
        [
            "saslStart": true,
            "mechanism": .string(self.mechanism.rawValue),
            "payload": .string(self.payload),
        ]
    }
}
