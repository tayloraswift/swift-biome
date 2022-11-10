extension Mongo
{
    public
    struct ReplyStatusError:Error
    {
        public
        let message:String

        init(message:String)
        {
            self.message = message
        }
    }
}
extension Mongo.ReplyStatusError:CustomStringConvertible
{
    public
    var description:String
    {
        self.message.isEmpty ?
            "server responded with error status" :
            "server responded with error: '\(self.message)'"
    }
}
