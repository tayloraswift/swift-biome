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
        let database:Database.ID

        @inlinable public
        init(authentication:Authentication?,
            username:String,
            password:String,
            database:Database.ID = .admin)
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
    var user:Mongo.User.ID
    {
        .init(self.database, self.username)
    }
}
