import Atomics
import BSON
import NIOCore

extension Mongo
{
    final
    class MessageRouter
    {
        public
        enum CommunicationError:Error
        {
            case unsolicitedResponse(to:Int32)
            case timeout
        }

        private
        let counter:ManagedAtomic<Int32>
        private
        let timeout:Duration
        private
        var requests:[Int32: CheckedContinuation<OpMessage, Error>]

        init(timeout:Duration)
        {
            self.counter = .init(0)
            self.timeout = timeout
            self.requests = [:]
        }

        deinit
        {
            for continuation:CheckedContinuation<OpMessage, Error> in self.requests.values
            {
                continuation.resume(throwing: CommunicationError.timeout)
            }
        }
    }
}
extension Mongo.MessageRouter:ChannelInboundHandler
{
    typealias InboundIn = OpMessage
    typealias InboundOut = Never

    func channelRead(context:ChannelHandlerContext, data:NIOAny)
    {
        let message:OpMessage = self.unwrapInboundIn(data)
        let request:Int32 = message.header.responseTo
        if  let continuation:CheckedContinuation<OpMessage, Error> = 
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
    typealias OutboundIn = (Document, CheckedContinuation<OpMessage, Error>)
    typealias OutboundOut = ByteBuffer

    func write(context:ChannelHandlerContext, data:NIOAny, promise:EventLoopPromise<Void>?)
    {
        let (command, continuation):(Document, CheckedContinuation<OpMessage, Error>) = 
            self.unwrapOutboundIn(data)
        
        let id:Int32 = self.counter.loadThenWrappingIncrement(ordering: .relaxed)
        let message:OpMessage = .init(body: command, requestId: id)
        
        guard case nil = self.requests.updateValue(continuation, forKey: id)
        else
        {
            fatalError("unreachable: atomic counter is broken!")
        }

        var buffer:ByteBuffer = context.channel.allocator.buffer(
            capacity: .init(message.header.messageLength))
        
        message.write(to: &buffer)
        context.write(self.wrapOutboundOut(buffer), promise: promise)
        
        Task.init
        {
            [weak self, id, timeout] in

            try? await Task.sleep(for: timeout)
            if  let self:Mongo.MessageRouter,
                let continuation:CheckedContinuation<OpMessage, Error> = 
                    self.requests.removeValue(forKey: id)
            {
                continuation.resume(throwing: CommunicationError.timeout)
            }
        }
    }
}
