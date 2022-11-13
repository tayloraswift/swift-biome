import BSONEncoding
import SCRAM

extension Mongo.SASL
{
    struct Continue
    {
        let conversation:Int32
        let message:SCRAM.Message
    }
}
extension Mongo.SASL.Continue:MongoAuthenticationCommand
{
    var fields:BSON.Fields<[UInt8]>
    {
        [
            "saslContinue": true,
            "conversationId": .int32(self.conversation),
            "payload": .string(self.message.base64),
        ]
    }
}
