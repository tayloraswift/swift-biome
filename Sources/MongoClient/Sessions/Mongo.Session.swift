import NIOCore

extension Mongo
{
    // not sendable! not even a little bit!
    public
    struct Session:Identifiable
    {
        let connection:Connection
        private
        let manager:Manager

        public
        var id:ID
        {
            self.manager.id
        }
    }
}
extension Mongo.Session
{
    init(connection:Mongo.Connection, cluster:Mongo.Cluster, id:ID)
    {
        self.connection = connection
        self.manager = .init(cluster: cluster, id: id)
    }

    class Manager
    {
        // TODO: implement time gossip
        private
        let cluster:Mongo.Cluster
        let id:ID

        init(cluster:Mongo.Cluster, id:ID)
        {
            self.cluster = cluster
            self.id = id
        }

        fileprivate
        func reset(timeout:ContinuousClock.Instant)
        {
            Task.init
            {
                [id] in await self.cluster.update(session: id, timeout: timeout)
            }
        }
        deinit
        {
            Task.init
            {
                [id, cluster] in await cluster.release(session: id)
            }
        }
    }
}


extension Mongo.Session
{
    private
    func timeout() -> ContinuousClock.Instant
    {
        // allow 1 min padding time
        let minutes:Int = max(0, self.connection.instance.logicalSessionTimeoutMinutes - 1)
        return .now.advanced(by: .seconds(minutes * 60))
    }

    public
    func run<Command>(command:Command) async throws -> Command.Response
        where Command:AdministrativeCommand
    {
        let timeout:ContinuousClock.Instant = self.timeout()
        let message:Mongo.Message<ByteBufferView> = try await self.connection.run(
            command: command, against: .admin,
            transaction: nil,
            session: self.id)
        self.manager.reset(timeout: timeout)
        return try Command.decode(message: message)
    }
    
    public
    func run<Command>(command:Command, 
        against database:Mongo.Database) async throws -> Command.Response
        where Command:DatabaseCommand
    {
        let timeout:ContinuousClock.Instant = self.timeout()
        let message:Mongo.Message<ByteBufferView> = try await self.connection.run(
            command: command, against: database,
            transaction: nil,
            session: self.id)
        self.manager.reset(timeout: timeout)
        return try Command.decode(message: message)
    }
}
