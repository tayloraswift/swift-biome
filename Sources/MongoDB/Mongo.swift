import BSON

@_exported
import MongoClient

// public
// struct MongoDB 
// {
//     /// The name of the database.
//     public 
//     let name:String
//     let pool:any MongoConnectionPool

//     private
//     var transaction:MongoTransaction?
//     public private(set) 
//     var session:MongoClientSession?

//     /// The collection to execute commands on.
//     var namespace:MongoNamespace 
//     {
//         .init(to: "$cmd", inDatabase: self.name)
//     }

//     init(name:String, pool:any MongoConnectionPool,
//         transaction:MongoTransaction? = nil,
//         session:MongoClientSession? = nil)
//     {
//         self.transaction = transaction
//         self.session = session

//         self.name = name
//         self.pool = pool
//     }
// }

// extension MongoDB
// {
//     public static 
//     func connect(on group:any EventLoopGroup, settings:ConnectionSettings) async throws -> Self
//     {
//         .init(name: settings.targetDatabase ?? "admin", 
//             pool: try await MongoCluster.init(connectingTo: settings, eventLoopGroup: group))
//     }

//     public
//     func use(database name:String) -> Self
//     {
//         .init(name: name, pool: self.pool, 
//             transaction: self.transaction, 
//             session: self.session)
//     }
// }
// extension MongoDB
// {
//     public
//     enum CommandError:Error
//     {
//         case notTransactable(any MongoCommand.Type)
//         case notAdmin(any MongoAdministrativeCommand.Type)
//     }
    
//     @discardableResult
//     public 
//     func run<Command>(command:Command) async throws -> MongoServerReply 
//         where Command:MongoCommand
//     {
//         if Command.self is any MongoTransactableCommand.Type
//         {
//         }
//         else 
//         {
//             guard case nil = self.transaction
//             else
//             {
//                 throw CommandError.notTransactable(Command.self)
//             }
//         }
//         if  let command:any MongoAdministrativeCommand.Type = 
//                 Command.self as? any MongoAdministrativeCommand.Type
//         {
//             guard case "admin" = self.name
//             else
//             {
//                 // this would also error if sent over the wire
//                 throw CommandError.notAdmin(command)
//             }
//         }
        
//         let connection:MongoConnection = try await self.pool.next(for: .writable)
//         let reply:MongoServerReply = try await connection.execute(command.bson,
//             namespace: self.namespace,
//             in: self.transaction,
//             sessionId: connection.implicitSessionId)
//         try reply.assertOK()
//         return reply
//     }
// }
