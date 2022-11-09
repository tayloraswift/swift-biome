protocol MongoAuthenticationCommand:MongoCommand<Mongo.SASL.Response>
{
    associatedtype Response = Mongo.SASL.Response
}
