import Atomics
import BSON
import NIO

// struct MongoContextOption:ChannelOption 
// {
//     typealias Value = MongoClientContext
// }

final
class MongoRouter
{
    public
    enum CommunicationError:Error
    {
        case unsolicitedResponse(to:Int32)
    }

    private
    let counter:ManagedAtomic<Int32>
    private
    var requests:[Int32: CheckedContinuation<OpMessage, Error>]

    init()
    {
        self.counter = .init(0)
        self.requests = [:]
    }

    func channelInactive(context:ChannelHandlerContext) 
    {
        // TODO: fail all outstanding continuations
    }
}
extension MongoRouter:ChannelInboundHandler
{
    typealias InboundIn = OpMessage
    typealias InboundOut = Never

    func channelRead(context:ChannelHandlerContext, data:NIOAny)
    {
        let message:OpMessage = self.unwrapInboundIn(data)
        let request:Int32 = message.header.responseTo
        if let continuation:CheckedContinuation<OpMessage, Error> = self.requests[request]
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
extension MongoRouter:ChannelOutboundHandler
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
        // TODO: timeout
    }
}

struct MongoServerReplyDecoder:ByteToMessageDecoder 
{
    typealias InboundOut = OpMessage

    private 
    var header:MongoMessageHeader?

    init()
    {
        self.header = nil
    }

    mutating 
    func decode(context:ChannelHandlerContext, 
        buffer:inout ByteBuffer) throws -> DecodingState 
    {
        let header:MongoMessageHeader
        if let seen:MongoMessageHeader = self.header 
        {
            header = seen
        } 
        else if MongoMessageHeader.byteSize <= buffer.readableBytes
        {
            header = try buffer.assertReadMessageHeader()
        }
        else
        {
            return .needMoreData
        }

        guard case .message = header.opCode
        else
        {
            throw MongoProtocolParsingError.init(reason: .unsupportedOpCode)
        }

        let expected:Int32 = header.messageLength - MongoMessageHeader.byteSize

        if expected <= buffer.readableBytes 
        {
            self.header = nil
        }
        else 
        {
            self.header = header
            return .needMoreData
        }

        let message:OpMessage = try .init(reading: &buffer, header: header)
        context.fireChannelRead(self.wrapInboundOut(message))
        return .continue
    }

    mutating 
    func decodeLast(context:ChannelHandlerContext, 
        buffer:inout ByteBuffer, 
        seenEOF _:Bool) throws -> DecodingState 
    {
        return try decode(context: context, buffer: &buffer)
    }

    // TODO: this does not belong here but on the next handler
    func errorCaught(context:ChannelHandlerContext, error _:any Error) 
    {
        // So that it can take the remaining queries and re-try them
        context.close(promise: nil)
    }
}
