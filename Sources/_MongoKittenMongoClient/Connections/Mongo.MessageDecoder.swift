import NIOCore

extension Mongo
{
    struct MessageDecoder 
    {
        typealias InboundOut = OpMessage

        private 
        var header:MongoMessageHeader?

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
}
