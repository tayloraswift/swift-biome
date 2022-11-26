import NIOPosix
import MongoDB
import Testing

@main
enum Main:AsynchronousTests
{
    static
    func run(tests:inout Tests) async
    {
        let host:Mongo.Host = .init(name: "mongodb", port: 27017)
        let group:MultiThreadedEventLoopGroup = .init(numberOfThreads: 2)
        
        let cluster:Mongo.Cluster? = await tests.do(name: "bootstrap")
        {
            _ in try await Mongo.Cluster.init(
                settings: .init(
                    credentials: .init(authentication: .sasl(.sha256),
                        username: "root",
                        password: "password"),
                    timeout: .seconds(10)),
                servers: [host],
                group: group)
        }
        guard let cluster:Mongo.Cluster
        else
        {
            return
        }

        await tests.with(database: "databases", cluster: cluster)
        {
            (tests:inout Tests, database:Mongo.Database, builtin:[Mongo.Database]) in

            await tests.do(name: "create-database-by-collection")
            {
                _ in try await cluster.run(
                    command: Mongo.Create.init(collection: "placeholder"), 
                    against: database)
            }

            await tests.do(name: "list-database-names")
            {
                let names:[Mongo.Database] = try await cluster.run(
                    command: Mongo.ListDatabases.NameOnly.init())
                $0.assert(names **? builtin + [database], name: "names")
            }

            await tests.do(name: "list-databases")
            {
                let (size, databases):(Int, [Mongo.DatabaseMetadata]) = try await cluster.run(
                    command: Mongo.ListDatabases.init())
                $0.assert(size > 0, name: "nonzero-size")
                $0.assert(databases.map(\.database) **? builtin + [database], name: "names")
            }
        }

        await tests.with(database: "collection-insertion", cluster: cluster)
        {
            (tests:inout Tests, database:Mongo.Database, builtin:[Mongo.Database]) in

            let collection:Mongo.Collection = "ordinals"

            await tests.do(name: "insert-one")
            {
                let expected:Mongo.InsertResponse = .init(inserted: 1)
                let response:Mongo.InsertResponse = try await cluster.run(
                    command: Mongo.Insert<Ordinals>.init(collection: collection,
                        elements: .init(identifiers: 0 ..< 1)),
                    against: database)
                
                $0.assert(response ==? expected, name: "response")
            }

            await tests.do(name: "insert-multiple")
            {
                let expected:Mongo.InsertResponse = .init(inserted: 15)
                let response:Mongo.InsertResponse = try await cluster.run(
                    command: Mongo.Insert<Ordinals>.init(collection: collection,
                        elements: .init(identifiers: 1 ..< 16)),
                    against: database)
                
                $0.assert(response ==? expected, name: "response")
            }

            await tests.do(name: "insert-duplicate-id")
            {
                let expected:Mongo.InsertResponse = .init(inserted: 0,
                    writeErrors:
                    [
                        .init(index: 0,
                            message:
                            """
                            E11000 duplicate key error collection: \
                            \(database).\(collection) index: _id_ dup key: { _id: 0 }
                            """,
                            code: 11000),
                    ])
                let response:Mongo.InsertResponse = try await cluster.run(
                    command: Mongo.Insert<Ordinals>.init(collection: collection,
                        elements: .init(identifiers: 0 ..< 1)),
                    against: database)
                
                $0.assert(response ==? expected, name: "response")
            }

            await tests.do(name: "insert-ordered")
            {
                let expected:Mongo.InsertResponse = .init(inserted: 8,
                    writeErrors:
                    [
                        .init(index: 8,
                            message:
                            """
                            E11000 duplicate key error collection: \
                            \(database).\(collection) index: _id_ dup key: { _id: 0 }
                            """,
                            code: 11000),
                    ])
                let response:Mongo.InsertResponse = try await cluster.run(
                    command: Mongo.Insert<Ordinals>.init(collection: collection,
                        elements: .init(identifiers: -8 ..< 32)),
                    against: database)
                
                $0.assert(response ==? expected, name: "response")
            }

            await tests.do(name: "insert-unordered")
            {
                let expected:Mongo.InsertResponse = .init(inserted: 24,
                    writeErrors: (8 ..< 32).map
                    {
                        .init(index: $0,
                            message:
                            """
                            E11000 duplicate key error collection: \
                            \(database).\(collection) index: _id_ dup key: { _id: \($0 - 16) }
                            """,
                            code: 11000)
                    })
                let response:Mongo.InsertResponse = try await cluster.run(
                    command: Mongo.Insert<Ordinals>.init(collection: collection,
                        elements: .init(identifiers: -16 ..< 32),
                        ordered: false),
                    against: database)
                
                $0.assert(response ==? expected, name: "response")
            }
        }

        await tests.with(database: "collection-iteration", cluster: cluster)
        {
            (tests:inout Tests, database:Mongo.Database, builtin:[Mongo.Database]) in

            let collection:Mongo.Collection = "ordinals"
            let ordinals:Ordinals = .init(identifiers: 0 ..< 100)

            await tests.do(name: "initialize")
            {
                let expected:Mongo.InsertResponse = .init(inserted: 100)
                let response:Mongo.InsertResponse = try await cluster.run(
                    command: Mongo.Insert<Ordinals>.init(collection: collection,
                        elements: ordinals),
                    against: database)
                
                $0.assert(response ==? expected, name: "response")
            }
            // await tests.do(name: "single-batch")
            // {
            //     let expected:Mongo.Cursor<Ordinal> = .init(id: 0,
            //         namespace: .init(database, collection),
            //         elements: [Ordinal].init(ordinals.prefix(10)))
            //     let cursor:Mongo.Cursor<Ordinal> = try await cluster.run(
            //         command: Mongo.Find<Ordinal>.init(collection: collection,
            //             returning: .batch(of: 10)),
            //         against: database)

            //     $0.assert(cursor ==? expected, name: "cursor")
            // }
            await tests.do(name: "multiple-batches")
            {
                _ in

                let session:Mongo.Session = try await cluster.session(on: .any)

                for try await batch:[Ordinal] in try await session.run(
                    query: Mongo.Find<Ordinal>.init(collection: collection,
                        returning: 10),
                    against: database)
                {
                    print(batch)
                    break
                }
            }
        }

        try? await Task.sleep(for: .milliseconds(2000))
    }
}
