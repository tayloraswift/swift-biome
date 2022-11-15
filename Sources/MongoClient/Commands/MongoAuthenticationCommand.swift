protocol MongoAuthenticationCommand:MongoCommand<Mongo.SASLResponse>
{
    associatedtype Response = Mongo.SASLResponse
}
