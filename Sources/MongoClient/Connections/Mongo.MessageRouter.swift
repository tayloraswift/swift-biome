import Atomics
import BSON
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
            case unsolicitedResponse(to:MessageIdentifier)
            case timeout
        }

        private
        let counter:ManagedAtomic<Int32>
        private
        let timeout:Duration
        private
        var requests:
        [
            MessageIdentifier: CheckedContinuation<Mongo.Message<ByteBufferView>, Error>
        ]

        init(timeout:Duration)
        {
            // MongoDB uses 0 as the ‘nil’ id.
            self.counter = .init(1)
            self.timeout = timeout
            self.requests = [:]
        }

        deinit
        {
            for continuation:CheckedContinuation<Mongo.Message<ByteBufferView>, Error>
                in self.requests.values
            {
                continuation.resume(throwing: CommunicationError.timeout)
            }
        }
    }
}
extension Mongo.MessageRouter:ChannelInboundHandler
{
    typealias InboundIn = Mongo.Message<ByteBufferView>
    typealias InboundOut = Never

    func channelRead(context:ChannelHandlerContext, data:NIOAny)
    {
        let message:Mongo.Message<ByteBufferView> = self.unwrapInboundIn(data)
        let request:Mongo.MessageIdentifier = message.header.request
        if  let continuation:CheckedContinuation<Mongo.Message<ByteBufferView>, Error> = 
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
    typealias OutboundIn = (BSON.Fields<[UInt8]>, CheckedContinuation<Mongo.Message<ByteBufferView>, Error>)
    typealias OutboundOut = ByteBuffer

    func write(context:ChannelHandlerContext, data:NIOAny, promise:EventLoopPromise<Void>?)
    {
        let (fields, continuation):(BSON.Fields<[UInt8]>, CheckedContinuation<Mongo.Message<ByteBufferView>, Error>) = 
            self.unwrapOutboundIn(data)
        
        let id:Mongo.MessageIdentifier = .init(
            self.counter.loadThenWrappingIncrement(ordering: .relaxed))
        
        let command:BSON.Document<[UInt8]> = .init(fields)
        let message:Mongo.Message<[UInt8]> = .init(sections: .init(command),
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
        
        context.write(self.wrapOutboundOut(ByteBuffer.init(output.destination)),
            promise: promise)
        
        Task.init
        {
            [weak self, id, timeout] in

            try? await Task.sleep(for: timeout)
            if  let self:Mongo.MessageRouter,
                let continuation:CheckedContinuation<Mongo.Message<ByteBufferView>, Error> = 
                    self.requests.removeValue(forKey: id)
            {
                continuation.resume(throwing: CommunicationError.timeout)
            }
        }
    }
}
