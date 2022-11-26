/// A type that can encode a MongoDB command that can run against
/// an arbitrary database.
///
/// Command types that do not conform to this protocol are considered
/// administrative commands, and must run against the
/// ``Mongo/Database/.admin`` database. Therefore most library APIs only
/// allow you to specify an arbitrary database to execute against for
/// `MongoDatabaseCommand`s.
///
/// >   Note:
///     The database a command must run against determines its
///     “administrative”-ness. Users can run most administrative
///     commands in some form regardless of server privileges.
public
protocol MongoDatabaseCommand<Response>:MongoCommand
{
}
