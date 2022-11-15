extension Mongo
{
    public
    struct ServerError:Equatable, Error
    {
        public
        let message:String

        public
        init(message:String)
        {
            self.message = message
        }
    }
}
extension Mongo.ServerError:CustomStringConvertible
{
    public
    var description:String
    {
        self.message
    }
}
