/// A type that can encode a MongoDB command that can be run
/// as part of a session, which can be implicitly generated
/// if the command is sent to a server cluster at large.
public
protocol MongoImplicitSessionCommand<Response>:MongoSessionCommand
{
    /// The type of MongoDB instance this command must be sent to,
    /// in order for it to succeed.
    ///
    /// For example, some commands mutate database state, and
    /// therefore must be sent to a master node.
    static
    var node:Mongo.InstanceSelector { get }
}
