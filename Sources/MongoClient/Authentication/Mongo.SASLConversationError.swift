extension Mongo
{
    public
    struct SASLConversationError:Equatable, Error
    {
    }
}
extension Mongo.SASLConversationError:CustomStringConvertible
{
    public
    var description:String
    {
        "failed to complete SASL conversation"
    }
}
