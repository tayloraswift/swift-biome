extension Mongo
{
    @frozen public
    struct Credentials:Equatable, Sendable
    {
        public
        let authentication:Authentication?
        public
        let username:String
        public
        let password:String
        public
        let database:Database

        @inlinable public
        init(authentication:Authentication?,
            username:String,
            password:String,
            database:Database = .admin)
        {
            self.authentication = authentication
            self.username = username
            self.password = password
            self.database = database
        }
    }
}
extension Mongo.Credentials
{
    var user:Mongo.User
    {
        .init(self.database, self.username)
    }
}
