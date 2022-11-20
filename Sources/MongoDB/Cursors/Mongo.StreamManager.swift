extension Mongo
{
    @usableFromInline
    class StreamManager
    {
        let session:Session

        private(set)
        var cursor:Int64

        let namespace:Namespace
        let batching:Int
        let timeout:Mongo.Duration?

        init?(session:Session, cursor:Int64,
            namespace:Namespace,
            batching:Int,
            timeout:Mongo.Duration?)
        {
            self.session = session
            self.cursor = cursor

            guard self.cursor != 0
            else
            {
                return nil
            }

            self.namespace = namespace
            self.batching = batching
            self.timeout = timeout
        }

        deinit
        {
            guard self.cursor != 0
            else
            {
                return
            }

            let command:KillCursors = .init([self.cursor], collection: self.collection)

            print("deinitializing")
            Task.init
            {
                [session, database] in

                do
                {
                    let cursors:KillCursors.Response = try await session.run(command: command,
                        against: database)
                    print(cursors)
                }
                catch let error
                {
                    print(error)
                }
            }
        }
    }
}
extension Mongo.StreamManager
{
    var database:Mongo.Database.ID
    {
        self.namespace.database
    }
    var collection:Mongo.Collection.ID
    {
        self.namespace.collection
    }
    func get<Element>(more _:Element.Type) async throws -> [Element]?
        where Element:MongoDecodable
    {
        guard   let command:Mongo.Cursor<Element>.GetMore = .init(cursor: self.cursor,
                    collection: self.collection,
                    batching: self.batching,
                    timeout: self.timeout)
        else
        {
            return nil
        }

        let cursor:Mongo.Cursor<Element> = try await self.session.run(command: command,
            against: self.database)
        
        self.cursor = cursor.id

        return cursor.elements
    }
}
