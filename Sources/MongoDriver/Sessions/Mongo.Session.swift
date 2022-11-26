import MongoWire
import NIOCore

extension Mongo
{
    // not sendable! not even a little bit!
    public
    struct Session
    {
        private
        let connection:Connection
        private
        let manager:SessionManager

        init(connection:Connection, manager:SessionManager)
        {
            self.connection = connection
            self.manager = manager
        }
    }
}
extension Mongo.Session:Identifiable
{
    public
    var id:ID
    {
        self.manager.id
    }
}
extension Mongo.Session
{
    private
    func timeout() -> ContinuousClock.Instant
    {
        // allow 1 min padding time
        let timeout:Mongo.Minutes = self.connection.instance.logicalSessionTimeoutMinutes
        return .now.advanced(by: .minutes(max(0, timeout - 1)))
    }

    /// Runs a session command against the ``Mongo/Database/.admin`` database.
    public
    func run<Command>(command:Command) async throws -> Command.Response
        where Command:MongoSessionCommand
    {
        let timeout:ContinuousClock.Instant = self.timeout()
        let message:MongoWire.Message<ByteBufferView> = try await self.connection.run(
            command: command, against: .admin,
            transaction: nil,
            session: self.id)
        self.manager.extend(timeout: timeout)
        return try Command.decode(message: message)
    }
    
    /// Runs a session command against the specified database.
    public
    func run<Command>(command:Command, 
        against database:Mongo.Database) async throws -> Command.Response
        where Command:MongoDatabaseCommand
    {
        let timeout:ContinuousClock.Instant = self.timeout()
        let message:MongoWire.Message<ByteBufferView> = try await self.connection.run(
            command: command, against: database,
            transaction: nil,
            session: self.id)
        self.manager.extend(timeout: timeout)
        return try Command.decode(message: message)
    }
}
