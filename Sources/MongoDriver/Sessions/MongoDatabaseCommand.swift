/// A type that can encode a MongoDB command that can run against
/// an arbitrary database. ``Mongo/Database/.admin`` database.
///
/// The database a command must run against determines its
/// “administrative”-ness. Users can run most administrative commands
/// in some form regardless of server privileges.
///
/// It is safe, but non-sensical, to conform types to both this
/// protocol and ``MongoDatabaseCommand`` at the same time.
public
protocol MongoDatabaseCommand<Response>:MongoSessionCommand
{
}
