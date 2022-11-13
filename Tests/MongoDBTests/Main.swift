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
        
        await tests.group("main")
        {
            guard let cluster:Mongo.Cluster = await $0.cluster(hosts: host, group: group)
            else
            {
                return
            }

            let database:Mongo.Database = "test-database"

            await $0.do(name: "drop-database")
            {
                _ in
                try await cluster.run(command: Mongo.DropDatabase.init(), against: database)
                try await cluster.run(command: Mongo.Create.init(binding: "test"), 
                    against: database)

                print(try await cluster.run(command: Mongo.ListDatabases.init()).databases.map(\.name))

                try await cluster.run(command: Mongo.DropDatabase.init(), against: database)
                
                print(try await cluster.run(command: Mongo.ListDatabases.init()).databases.map(\.name))

                try await Task.sleep(for: .seconds(2))
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
