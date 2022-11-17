import BSON
import MongoWire
import NIOCore

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
        typealias InboundOut = MongoWire.Message<ByteBufferView>

        private 
        var header:MongoWire.Header?

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
        let header:MongoWire.Header
        if let seen:MongoWire.Header = self.header 
        {
            header = seen
        } 
        else if MongoWire.Header.size <= buffer.readableBytes
        {
            header = try buffer.readWithUnsafeInput
            {
                try $0.parse(as: MongoWire.Header.self)
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
        let message:MongoWire.Message<ByteBufferView> = try buffer.readWithInput
        {
            try $0.parse(as: MongoWire.Message<ByteBufferView>.self, header: header)
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
