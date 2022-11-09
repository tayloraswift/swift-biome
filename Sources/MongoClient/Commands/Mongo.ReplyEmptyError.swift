extension Mongo
{
    public
    struct ReplyEmptyError:Error
    {
    }
}
extension Mongo.ReplyEmptyError:CustomStringConvertible
{
    public
    var description:String
    {
        "empty MongoDB server reply"
    }
}
