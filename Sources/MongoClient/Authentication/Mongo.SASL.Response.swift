import BSONDecoding
import NIOCore
import SCRAM

extension Mongo.SASL
{
    struct Response
    {
        private
        let conversation:Int32
        let message:SCRAM.Message
        let done:Bool
    }
}
extension Mongo.SASL.Response
{
    func command(message:SCRAM.Message) -> Mongo.SASL.Continue
    {
        .init(conversation: self.conversation, message: message)
    }
}
extension Mongo.SASL.Response:MongoResponse
{
    init(from bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self.conversation = try bson["conversationId"].decode(to: Int32.self)
        self.message = try bson["payload"].decode
        {
            switch $0
            {
            case .string(let utf8):
                return .init(base64: utf8.bytes)
            case .binary(let binary):
                return .init(base64: binary.bytes)
            default:
                throw BSON.PrimitiveError<String>.init(variant: $0.type)
            }
        }
        self.done = try bson["done"].decode(to: Bool.self)
    }
}
