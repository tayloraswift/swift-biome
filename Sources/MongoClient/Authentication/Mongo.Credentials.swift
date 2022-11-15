extension Mongo
{
    @frozen public
    struct Credentials:Equatable, Sendable
    {
        public
        let authentication:Mongo.Authentication?
        public
        let username:String
        public
        let password:String
        public
        let database:Mongo.Database

        @inlinable public
        init(authentication:Mongo.Authentication?,
            username:String,
            password:String,
            database:Mongo.Database = .admin)
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
