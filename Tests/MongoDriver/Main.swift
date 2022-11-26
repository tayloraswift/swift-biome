import NIOPosix
import MongoDriver
import Testing

@main 
enum Main:AsynchronousTests
{
    static
    func run(tests:inout Tests) async
    {
        let host:Mongo.Host = .init(name: "mongodb", port: 27017)
        let group:MultiThreadedEventLoopGroup = .init(numberOfThreads: 2)
        
        await tests.group("authentication")
        {
            // since we do not perform any operations, this should succeed
            await $0.do(name: "none")
            {
                _ in try await Mongo.Cluster.init(
                    settings: .init(timeout: .seconds(10)),
                    servers: [host],
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
                    servers: [host],
                    group: group)
            }

            let x509:Mongo.Credentials = .init(authentication: .x509,
                username: "root",
                password: "password")
            await $0.do(name: "unsupported", 
                expecting: Mongo.ConnectivityError.init(selector: .master, 
                    errors:
                    [
                        (
                            host, 
                            Mongo.AuthenticationError.init(
                                Mongo.AuthenticationUnsupportedError.init(.x509),
                                credentials: x509)
                        )
                    ]))
            {
                _ in _ = try await Mongo.Cluster.init(
                    settings: .init(credentials: x509,
                        timeout: .seconds(10)),
                    servers: [host],
                    group: group)
            }

            let sha256:Mongo.Credentials = .init(authentication: .sasl(.sha256),
                username: "root",
                password: "1234")
            await $0.do(name: "wrong-password",
                expecting: Mongo.ConnectivityError.init(selector: .master, 
                    errors:
                    [
                        (
                            host, 
                            Mongo.AuthenticationError.init(
                                Mongo.ServerError.init(message: "Authentication failed."),
                                credentials: sha256)
                        )
                    ]))
            {
                _ in _ = try await Mongo.Cluster.init(
                    settings: .init(credentials: sha256,
                        timeout: .seconds(10)),
                    servers: [host],
                    group: group)
            }

            await $0.do(name: "scram-sha256")
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
        }
    }
}
