extension Mongo
{
    // not sendable! not even a little bit!
    public
    struct Session
    {
        let connection:Connection
        private
        let manager:Manager

        var id:SessionIdentifier
        {
            self.manager.id
        }
    }
}
extension Mongo.Session
{
    init(connection:Mongo.Connection, cluster:Mongo.Cluster, id:SessionIdentifier)
    {
        self.connection = connection
        self.manager = .init(cluster: cluster, id: id)
    }

    class Manager
    {
        // TODO: implement time gossip
        private
        let cluster:Mongo.Cluster
        let id:SessionIdentifier

        init(cluster:Mongo.Cluster, id:SessionIdentifier)
        {
            self.cluster = cluster
            self.id = id
        }

        fileprivate
        func rejuvenate(timeout:ContinuousClock.Instant)
        {
            Task.init
            {
                print("UPDATING", self.id)
                await self.cluster.update(session: self.id, timeout: timeout)
            }
        }
        deinit
        {
            let id:SessionIdentifier = self.id
            let cluster:Mongo.Cluster = self.cluster
            Task.init
            {
                print("RELEASING", id)
                await cluster.release(session: id)
            }
        }
    }
}


extension Mongo.Session
{
    private
    func timeout() -> ContinuousClock.Instant
    {
        if  let minutes:Int = self.connection.handshake.logicalSessionTimeoutMinutes
        {
            // allow 1 min padding time
            let minutes:Int = max(0, minutes - 1)
            return .now.advanced(by: .seconds(minutes * 60))
        }
        else
        {
            fatalError("unsupported mongodb version")
        }
    }

    public
    func run<Command>(command:Command) async throws -> Command.Success
        where Command:AdministrativeCommand
    {
        let timeout:ContinuousClock.Instant = self.timeout()
        let reply:OpMessage = try await self.connection.run(command: command.bson,
            against: .administrativeCommand,
            transaction: nil,
            session: self.id)
        self.manager.rejuvenate(timeout: timeout)
        return try Command.decode(reply: reply)
    }
    
    public
    func run<Command>(command:Command, 
        against database:Mongo.Database) async throws -> Command.Success
        where Command:DatabaseCommand
    {
        let timeout:ContinuousClock.Instant = self.timeout()
        let reply:OpMessage = try await self.connection.run(command: command.bson,
            against: .init(to: "", inDatabase: database.name),
            transaction: nil,
            session: self.id)
        self.manager.rejuvenate(timeout: timeout)
        return try Command.decode(reply: reply)
    }
}