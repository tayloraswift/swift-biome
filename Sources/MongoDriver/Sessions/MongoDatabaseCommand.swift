/// A type that can encode a MongoDB command that can run against
/// an arbitrary database.
public
protocol MongoDatabaseCommand<Response>:MongoSessionCommand
{
}
