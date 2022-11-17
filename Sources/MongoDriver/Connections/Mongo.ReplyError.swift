import BSON

extension Mongo
{
    public
    enum ReplyError:Equatable, Error
    {
        case noDocuments
        case multipleDocuments
        case invalidStatusType(BSON)
    }
}
extension Mongo.ReplyError:CustomStringConvertible
{
    public
    var description:String
    {
        switch self
        {
        case .noDocuments:
            return "reply contained no documents"
        case .multipleDocuments:
            return "reply contained multiple documents"
        case .invalidStatusType(let variant):
            return "server returned status code of type '\(variant)'"
        }
    }
}
