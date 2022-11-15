import NIOPosix
import MongoDB
import Testing

@main 
enum Main
{
    static
    func main() async throws
    {
        var tests:UnitTests = .init()

        let host:Mongo.Host = .init("mongodb", 27017)
        let group:MultiThreadedEventLoopGroup = .init(numberOfThreads: 2)
        
        let cluster:Mongo.Cluster? = await tests.group("authentication")
        {
            // since we do not perform any operations, this should succeed
            await $0.do(name: "none")
            {
                _ in try await Mongo.Cluster.init(
                    settings: .init(timeout: .seconds(10)),
                    hosts: .standard([host]),
                    group: group)
            }

            await $0.do(name: "defaulted")
            {
                _ in try await Mongo.Cluster.init(
                    settings: .init(
                        credentials: .init(authentication: nil,
                            username: "root",
                            password: "password"),
                        timeout: .seconds(10)),
                    hosts: .standard([host]),
                    group: group)
            }

            let x509:Mongo.Credentials = .init(authentication: .x509,
                username: "root",
                password: "password")
            await $0.do(expecting: Mongo.ConnectivityError.init(selector: .master, 
                    errors:
                    [
                        (
                            host, 
                            Mongo.AuthenticationError.init(
                                Mongo.AuthenticationUnsupportedError.init(.x509),
                                credentials: x509)
                        )
                    ]),
                name: "unsupported")
            {
                _ in _ = try await Mongo.Cluster.init(
                    settings: .init(credentials: x509,
                        timeout: .seconds(10)),
                    hosts: .standard([host]),
                    group: group)
            }

            let sha256:Mongo.Credentials = .init(authentication: .sasl(.sha256),
                username: "root",
                password: "1234")
            await $0.do(expecting: Mongo.ConnectivityError.init(selector: .master, 
                    errors:
                    [
                        (
                            host, 
                            Mongo.AuthenticationError.init(
                                Mongo.ServerError.init(message: "Authentication failed."),
                                credentials: sha256)
                        )
                    ]),
                name: "wrong-password")
            {
                _ in _ = try await Mongo.Cluster.init(
                    settings: .init(credentials: sha256,
                        timeout: .seconds(10)),
                    hosts: .standard([host]),
                    group: group)
            }

            return await $0.do(name: "scram-sha256")
            {
                _ in try await Mongo.Cluster.init(
                    settings: .init(
                        credentials: .init(authentication: .sasl(.sha256),
                            username: "root",
                            password: "password"),
                        timeout: .seconds(10)),
                    hosts: .standard([host]),
                    group: group)
            }
        }

        guard let cluster:Mongo.Cluster
        else
        {
            return
        }

        await tests.group("databases")
        {
            let database:Mongo.Database = "test-database"

            await $0.do(name: "drop-database-non-existent")
            {
                _ in try await cluster.run(command: Mongo.DropDatabase.init(),
                    against: database)
            }
            await $0.do(name: "create-collection")
            {
                _ in try await cluster.run(command: Mongo.Create.init(binding: "test"), 
                    against: database)
            }

            await $0.do(name: "list-databases")
            {
                let names:[Mongo.Database] = try await cluster.run(command: Mongo.ListDatabases.init())
                    .databases.map(\.database)
                $0.assert(names ..? ["admin", "config", "local", database])
            }

            await $0.do(name: "list-collections")
            {
                _ in
                let cursor:Mongo.Cursor = try await cluster.run(command: Mongo.ListCollections.init(),
                    against: database)
                print(cursor)
            }

            await $0.do(name: "drop-database")
            {
                try await cluster.run(command: Mongo.DropDatabase.init(), against: database)
                let names:[Mongo.Database] = try await cluster.run(command: Mongo.ListDatabases.init())
                    .databases.map(\.database)
                $0.assert(names ..? ["admin", "config", "local"])
            }
        }

        try tests.summarize()
    }
}
extension UnitTests
{
    mutating
    func cluster(hosts:Mongo.Host..., group:MultiThreadedEventLoopGroup) async -> Mongo.Cluster?
    {
        await self.do(name: "connect")
        {
            _ in try await .init(
                settings: .init(
                    credentials: .init(authentication: nil,
                        username: "root",
                        password: "password"),
                    timeout: .seconds(10)),
                hosts: .standard(hosts),
                group: group)
        }
    }

    // mutating
    // func test<Failure, Unexpected>(name:String, hosts:Mongo.Host..., failure:Failure,
    //     with test:() async throws -> Unexpected) async
    //     where Failure:Equatable & Error
    // {
    //     await self.do(expecting: failure, name: name)
    //     {
    //         let cluster:Mongo.Cluster = 
    //         _ in _ = try decode(try .init(fields: try bson.parse()))
    //     }
    // }
    // mutating
    // func test<Expected>(name:String, decoding bson:BSON.Document<[UInt8]>,
    //     expecting expected:Expected,
    //     decoder decode:(BSON.Dictionary<ArraySlice<UInt8>>) throws -> Expected)
    //     where Expected:Equatable
    // {
    //     self.do(name: name)
    //     {
    //         let decoded:Expected = try decode(try .init(fields: try bson.parse()))
    //         $0.assert(expected == decoded, name: "\(name).value")
    //     }
    // }
}
