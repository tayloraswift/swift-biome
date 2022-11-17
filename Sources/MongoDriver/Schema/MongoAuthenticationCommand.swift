/// A type that can encode a MongoDB authentication command. Authentication commands
/// always return an instance of ``Mongo/SASLResponse``.
///
/// Not to be confused with ``MongoAdministrativeCommand``.
protocol MongoAuthenticationCommand:MongoCommand<Mongo.SASLResponse>
{
    associatedtype Response = Mongo.SASLResponse
}
