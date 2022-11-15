import TraceableErrors

extension Mongo
{
    public
    struct AuthenticationError:Error
    {
        public
        let underlying:any Error
        public
        let credentials:Credentials

        public
        init(_ underlying:any Error, credentials:Credentials)
        {
            self.underlying = underlying
            self.credentials = credentials
        }
    }
}
extension Mongo.AuthenticationError:Equatable
{
    public static
    func == (lhs:Self, rhs:Self) -> Bool
    {
        lhs.credentials == rhs.credentials &&
        lhs.underlying == rhs.underlying
    }
}
extension Mongo.AuthenticationError:TraceableError
{
    public
    var notes:[String]
    {
        [
            """
            user-specified authentication mode was \
            '\(self.credentials.authentication?.description ?? "default")'
            """,

            """
            while authenticating user '\(self.credentials.username)' in database \
            '\(self.credentials.database)'
            """,
        ]
    }
}
