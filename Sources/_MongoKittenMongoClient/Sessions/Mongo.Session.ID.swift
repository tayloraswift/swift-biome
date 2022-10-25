import BSON
import NIOCore

extension Mongo.Session
{
    public 
    struct ID:Hashable, Sendable 
    {
        let low:UInt64
        let high:UInt64

        static
        var _random:Self
        {
            .init()
        }

        init() 
        {
            self.low = .random(in: .min ... .max)
            self.high = .random(in: .min ... .max)
        }

        private
        var binary:Binary
        {
            var buffer:ByteBuffer = .init()
            buffer.reserveCapacity(16)
            buffer.writeInteger(self.low)
            buffer.writeInteger(self.high)
            return .init(subType: .uuid, buffer: buffer)
        }

        var bson:Document
        {
            [
                "id": self.binary
            ]
        }
    }
}