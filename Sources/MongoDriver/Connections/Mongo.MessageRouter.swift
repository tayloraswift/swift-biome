import Atomics
import BSONEncoding
import MongoWire
import NIOCore

extension Mongo
{
    final
    class MessageRouter
    {
        public
        enum CommunicationError:Error
        {
            case unsolicitedResponse(to:MongoWire.MessageIdentifier)
            case timeout
        }

        private
        let counter:ManagedAtomic<Int32>
        private
        let timeout:Milliseconds
        private
        var requests:
        [
            MongoWire.MessageIdentifier:
                CheckedContinuation<MongoWire.Message<ByteBufferView>, Error>
        ]

        init(timeout:Milliseconds)
        {
            // MongoDB uses 0 as the ‘nil’ id.
            self.counter = .init(1)
            self.timeout = timeout
            self.requests = [:]
        }

        deinit
        {
            for continuation:CheckedContinuation<MongoWire.Message<ByteBufferView>, Error>
                in self.requests.values
            {
                continuation.resume(throwing: CommunicationError.timeout)
            }
        }
    }
}
extension Mongo.MessageRouter:ChannelInboundHandler
{
    typealias InboundIn = MongoWire.Message<ByteBufferView>
    typealias InboundOut = Never

    func channelRead(context:ChannelHandlerContext, data:NIOAny)
    {
        let message:MongoWire.Message<ByteBufferView> = self.unwrapInboundIn(data)
        let request:MongoWire.MessageIdentifier = message.header.request
        if  let continuation:CheckedContinuation<MongoWire.Message<ByteBufferView>, Error> = 
                self.requests.removeValue(forKey: request)
        {
            continuation.resume(returning: message)
        }
        else
        {
            context.fireErrorCaught(CommunicationError.unsolicitedResponse(to: request))
            return
        }
    }
}
extension Mongo.MessageRouter:ChannelOutboundHandler
{
    typealias OutboundIn =
    (
        BSON.Fields,
        CheckedContinuation<MongoWire.Message<ByteBufferView>, Error>
    )
    typealias OutboundOut = ByteBuffer

    func write(context:ChannelHandlerContext, data:NIOAny, promise:EventLoopPromise<Void>?)
    {
        let (command, continuation):OutboundIn = self.unwrapOutboundIn(data)
        
        let id:MongoWire.MessageIdentifier = .init(self.counter.loadThenWrappingIncrement(
            ordering: .relaxed))
        let message:MongoWire.Message<[UInt8]> = .init(sections: .init(.init(command)),
            checksum: false,
            id: id)
        
        guard case nil = self.requests.updateValue(continuation, forKey: id)
        else
        {
            fatalError("unreachable: atomic counter is broken!")
        }

        var output:BSON.Output<ByteBufferView> = .init(
            preallocated: .init(context.channel.allocator.buffer(
                capacity: .init(message.header.size))))
        
        output.serialize(message: message)
        context.writeAndFlush(self.wrapOutboundOut(ByteBuffer.init(output.destination)),
            promise: promise)
        
        Task.init
        {
            [weak self, id, timeout] in

            try? await Task.sleep(for: .milliseconds(timeout))
            if  let self:Mongo.MessageRouter,
                let continuation:CheckedContinuation<MongoWire.Message<ByteBufferView>, Error> = 
                    self.requests.removeValue(forKey: id)
            {
                continuation.resume(throwing: CommunicationError.timeout)
            }
        }
    }
}
