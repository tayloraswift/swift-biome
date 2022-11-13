import BSONEncoding
import SCRAM

extension Mongo.SASL
{
    struct Start
    {
        let mechanism:Mongo.SASL
        let scram:SCRAM.Start

        init(mechanism:Mongo.SASL, scram:SCRAM.Start)
        {
            self.mechanism = mechanism
            self.scram = scram
        }
    }
}
extension Mongo.SASL.Start:MongoAuthenticationCommand
{
    var fields:BSON.Fields<[UInt8]>
    {
        [
            "saslStart": true,
            "mechanism": .string(self.mechanism.description),
            "payload": .string(self.scram.message.base64),
            "options":
            [
                "skipEmptyExchange": true,
            ],
        ]
    }
}
