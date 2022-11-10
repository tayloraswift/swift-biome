import BSONDecoding
import NIOCore

extension Mongo.SASL
{
    struct Response
    {
        private
        let conversation:Int32
        let payload:String
        let done:Bool
    }
}
extension Mongo.SASL.Response
{
    func command(payload:String) -> Mongo.SASL.Continue
    {
        .init(conversation: self.conversation, payload: payload)
    }
}
extension Mongo.SASL.Response:MongoResponse
{
    init(from bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self.conversation = try bson["conversationId"].decode(to: Int32.self)
        self.payload = try bson["payload"].decode
        {
            switch $0
            {
            case .string(let utf8):
                return utf8.description
            case .binary(let binary):
                return .init(decoding: binary.bytes, as: Unicode.UTF8.self)
            default:
                throw BSON.PrimitiveError<String>.init(variant: $0.type)
            }
        }
        self.done = try bson["done"].decode(to: Bool.self)
    }
}
