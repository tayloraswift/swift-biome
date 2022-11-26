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
    func encode(to bson:inout BSON.Fields)
    {
        bson["saslStart"] = true
        bson["mechanism"] = self.mechanism
        bson["payload"] = self.scram.message.base64
        bson["options"] = ["skipEmptyExchange": true]
    }
}
