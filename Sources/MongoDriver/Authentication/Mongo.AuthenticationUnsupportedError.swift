extension Mongo
{
    public
    struct AuthenticationUnsupportedError:Equatable, Error
    {
        public
        let authentication:Authentication

        public
        init(_ authentication:Authentication)
        {
            self.authentication = authentication
        }
    }
}
extension Mongo.AuthenticationUnsupportedError:CustomStringConvertible
{
    public
    var description:String
    {
        "unsupported authentication mechanism '\(self.authentication)'"
    }
}
