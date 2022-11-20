extension Mongo
{
    /// Ways to discover members of a MongoDB deployment.
    @frozen public
    enum Discovery:Sendable
    {
        /// A list of MongoDB servers.
        case standard(servers:[Mongo.Host])
        /// A hostname corresponding to a DNS SRV record to be queried
        /// in order to obtain a list of MongoDB servers.
        case seeded(srv:String, nameserver:Mongo.Host?)
    }
}
