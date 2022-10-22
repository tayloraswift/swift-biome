import BSON
import MongoCore

extension MongoServerReply
{
    func decode<Command>(for _:Command.Type) throws -> Command.Success 
        where Command:MongoCommand
    {
        if case .message(let reply) = self
        {
            return try Command.decode(reply: reply)
        }
        else
        {
            fatalError("unsupported mongodb version")
        }
    }
}
extension OpMessage
{
    var first:Document?
    {
        for section:Section in self.sections
        {
            switch section
            {
            case .body(let document):
                return document
            case .sequence(let sequence):
                if let document:Document = sequence.documents.first
                {
                    return document
                }
            }
        }
        return nil
    }
}

extension Document
{
    private
    var isOk:Bool
    {
        guard let primitive:any Primitive = self["ok"]
        else
        {
            return false
        }
        switch primitive
        {
        case let double as Double:
            return double == 1
        case let int as Int32:
            return int == 1
        case let int as Int:
            return int == 1
        case let bool as Bool:
            return bool
        default:
            return false
        }
    }
    func status() throws
    {
        guard self.isOk
        else
        {
            throw MongoCommandError.server(message: self["errmsg"] as? String)
        }
    }
}

public
enum MongoCommandError:Error
{
    case emptyReply
    case server(message:String?)
}
public
enum MongoCommandColor
{
    case nonmutating
    case mutating
}
public
protocol MongoCommand<Success>
{
    associatedtype Success = Void

    static
    var color:MongoCommandColor { get }
    var bson:Document { get }

    static
    func decode(reply:OpMessage) throws -> Success
}
extension MongoCommand<Void>
{
    public static
    func decode(reply:OpMessage) throws
    {
        guard let document:Document = reply.first
        else
        {
            throw MongoCommandError.emptyReply
        }

        try document.status()
    }
}


public
protocol MongoTransactableCommand:MongoCommand
{
}
