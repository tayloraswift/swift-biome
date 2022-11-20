import BSONEncoding
import SCRAM

extension Mongo
{
    struct SASLStart
    {
        let mechanism:Mongo.Authentication.SASL
        let scram:SCRAM.Start

        init(mechanism:Mongo.Authentication.SASL, scram:SCRAM.Start)
        {
            self.mechanism = mechanism
            self.scram = scram
        }
    }
}
extension Mongo.SASLStart:MongoAuthenticationCommand
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
