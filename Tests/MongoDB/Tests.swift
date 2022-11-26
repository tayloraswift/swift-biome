import MongoDB
import Testing

extension Tests
{
    mutating
    func with(database:Mongo.Database, cluster:Mongo.Cluster,
        running test:@Sendable (inout Self, Mongo.Database, [Mongo.Database]) async -> ()) async
    {
        await self.group(database.name)
        {
            await $0.do(name: "drop-database-non-existent")
            {
                _ in try await cluster.run(command: Mongo.DropDatabase.init(),
                    against: database)
            }

            let databases:[Mongo.Database] = ["admin", "config", "local"]

            await test(&$0, database, databases)

            await $0.do(name: "drop-database")
            {
                try await cluster.run(command: Mongo.DropDatabase.init(), against: database)
                let names:[Mongo.Database] = try await cluster.run(
                    command: Mongo.ListDatabases.NameOnly.init())
                $0.assert(names ..? databases, name: "names")
            }
        }
    }
}
