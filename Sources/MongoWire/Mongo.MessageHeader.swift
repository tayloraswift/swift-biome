import BSON

extension Mongo
{
    @frozen public
    struct MessageHeader:Identifiable, Sendable
    {
        /// The number of bytes in the message body, *not* including the header.
        public
        let count:Int
        /// The identifier for this message.
        public
        let id:MessageIdentifier
        /// The request this message is a response to.
        public
        let request:MessageIdentifier
        /// The type of this message.
        public
        let type:MessageType

        @inlinable public
        init(count:Int, id:MessageIdentifier, 
            request:MessageIdentifier = .none,
            type:MessageType = .message)
        {
            self.count = count
            self.id = id
            self.request = request
            self.type = type
        }
    }
}
extension Mongo.MessageHeader
{
    /// The size, 16 bytes, of a MongoDB message header.
    public static
    let size:Int = 16

    @inlinable public
    var size:Int32
    {
        .init(Self.size + self.count)
    }

    @inlinable public
    init(size:Int32, id:Int32, request:Int32, type:Int32) throws
    {
        guard let type:Mongo.MessageType = .init(rawValue: type)
        else
        {
            throw Mongo.MessageTypeError.init(invalid: type)
        }
        self.init(count: Int.init(size) - Self.size, id: .init(id), request: .init(request), 
            type: type)
    }
}

extension BSON.Input
{
    @inlinable public mutating
    func parse(
        as _:Mongo.MessageHeader.Type = Mongo.MessageHeader.self) throws -> Mongo.MessageHeader
    {
        // total size, including this
        let size:Int32 = try self.parse(as: Int32.self)
        let id:Int32 = try self.parse(as: Int32.self)
        let request:Int32 = try self.parse(as: Int32.self)
        let type:Int32 = try self.parse(as: Int32.self)
        return try .init(size: size, id: id, request: request, type: type)
    }
}
extension BSON.Output
{
    @inlinable public mutating
    func serialize(header:Mongo.MessageHeader)
    {
        // the `as` coercions are here to prevent us from accidentally
        // changing the types of the various integers, which ``serialize(integer:)``
        // depends on.
        self.serialize(integer: header.size as Int32)
        self.serialize(integer: header.id.value as Int32)
        self.serialize(integer: header.request.value as Int32)
        self.serialize(integer: header.type.rawValue as Int32)
    }
}
