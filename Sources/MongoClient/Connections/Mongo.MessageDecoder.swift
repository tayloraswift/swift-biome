import NIOCore
import BSON

extension ByteBuffer
{
    mutating
    func readWithInput<T>(
        parser parse:(inout BSON.Input<ByteBufferView>) throws -> T) rethrows -> T
    {
        var input:BSON.Input<ByteBufferView> = .init(self.readableBytesView)
        let parsed:T = try parse(&input)
        self.moveReaderIndex(forwardBy: input.source.distance(from: input.source.startIndex,
            to: input.index))
        return parsed
    }
    mutating
    func readWithUnsafeInput<T>(
        parser parse:(inout BSON.Input<UnsafeRawBufferPointer>) throws -> T) rethrows -> T
    {
        try self.readWithUnsafeReadableBytes
        {
            (buffer:UnsafeRawBufferPointer) throws -> (Int, T) in

            var input:BSON.Input<UnsafeRawBufferPointer> = .init(buffer)
            let parsed:T = try parse(&input)
            let advanced:Int = input.source.distance(from: input.source.startIndex,
                to: input.index)
            return (advanced, parsed)
        }
    }
}

extension Mongo
{
    struct MessageDecoder 
    {
        typealias InboundOut = Mongo.Message<ByteBufferView>

        private 
        var header:MessageHeader?

        init()
        {
            self.header = nil
        }
    }
}
extension Mongo.MessageDecoder:ByteToMessageDecoder
{
    mutating 
    func decode(context:ChannelHandlerContext, 
        buffer:inout ByteBuffer) throws -> DecodingState 
    {
        let header:Mongo.MessageHeader
        if let seen:Mongo.MessageHeader = self.header 
        {
            header = seen
        } 
        else if Mongo.MessageHeader.size <= buffer.readableBytes
        {
            header = try buffer.readWithUnsafeInput
            {
                try $0.parse(as: Mongo.MessageHeader.self)
            }
        }
        else
        {
            return .needMoreData
        }

        guard header.count <= buffer.readableBytes 
        else 
        {
            self.header = header
            return .needMoreData
        }

        self.header = nil
        let message:Mongo.Message<ByteBufferView> = try buffer.readWithInput
        {
            try $0.parse(as: Mongo.Message<ByteBufferView>.self, header: header)
        }
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
}
