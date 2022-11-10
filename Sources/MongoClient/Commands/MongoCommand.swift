import BSONDecoding
import BSONEncoding
import MongoWire
import NIOCore

/// A type that can encode a MongoDB command document.
public
protocol MongoCommand<Response>:Sendable
{
    /// The server response this command expects to receive.
    ///
    /// >   Note:
    ///     By convention, the library refers to a decoded message as a *response*,
    ///     and an undecoded message as a *reply*.
    associatedtype Response:Sendable = Void

    /// The basic document fields constituting this command. The library may add
    /// additional fields to this list before sending a request.
    var fields:BSON.Fields<[UInt8]> { get }

    /// A hook to decode an untyped server reply to a typed ``Response``.
    /// This is a static function instead of a requirement on ``Response`` to
    /// permit ``Void`` responses.
    ///
    /// Commands with responses conforming to ``MongoResponse`` will receive
    /// a default implementation for this requirement.
    static
    func decode(reply:BSON.Dictionary<ByteBufferView>) throws -> Response
}
extension MongoCommand<Void>
{
    /// Does nothing, ignoring the supplied decoding container.
    @inlinable public static
    func decode(reply _:BSON.Dictionary<ByteBufferView>)
    {
    }
}
extension MongoCommand where Response:MongoResponse
{
    /// Delegates to the ``Response`` type’s ``MongoResponse/.init(from:)`` initializer.
    @inlinable public static
    func decode(reply:BSON.Dictionary<ByteBufferView>) throws -> Response
    {
        try .init(from: reply)
    }
}
extension MongoCommand
{
    public static
    func decode(message:Mongo.Message<ByteBufferView>) throws -> Response
    {
        guard let document:BSON.Document<ByteBufferView> = message.documents.first
        else
        {
            throw Mongo.ReplyEmptyError.init()
        }
        if message.documents.count > 1
        {
            fatalError("unimplemented: multiple documents in message")
        }

        let dictionary:BSON.Dictionary<ByteBufferView> = try .init(fields: try document.parse())
        let ok:Bool = try dictionary["ok"].decode
        {
            switch $0
            {
            case .bool(true), .int32(1), .int64(1), .double(1.0):
                return true
            case .decimal128(_):
                fatalError("unimplemented: cannot understand 'decimal128' status code")
            default:
                return false
            }
        }
        if ok
        {
            return try Self.decode(reply: dictionary)
        }
        else
        {
            throw Mongo.ReplyStatusError.init(
                message: dictionary.items["errmsg"]?.as(String.self) ?? "")
        }
    }
}


public
protocol SessionCommand:MongoCommand
{
    /// The kind of node this command must be sent to, in order for
    /// it to succeed.
    static
    var node:Mongo.Cluster.Role { get }
}

public
protocol MongoTransactableCommand:SessionCommand
{
}
public
protocol DatabaseCommand:SessionCommand
{
}
public
protocol AdministrativeCommand:SessionCommand
{
}
