/// A type that can encode a MongoDB command that can be run
/// as part of a session.
///
/// A type that conforms to this protocol, but not ``MongoDatabaseCommand``,
/// is considered an administrative command, and must run against the
/// ``Mongo/Database/.admin`` database. Therefore most library APIs only
/// allow you to specify an arbitrary database to execute against for
/// ``MongoDatabaseCommand``s.
///
/// The database a command must run against determines its
/// “administrative”-ness. Users can run most administrative commands
/// in some form regardless of server privileges.
public
protocol MongoSessionCommand<Response>:MongoCommand
{
    /// The type of MongoDB instance this command must be sent to,
    /// in order for it to succeed.
    ///
    /// For example, some commands mutate database state, and
    /// therefore must be sent to a master instance.
    static
    var node:Mongo.InstanceSelector { get }
}
