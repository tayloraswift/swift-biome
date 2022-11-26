import MongoSchema

extension Mongo
{
    public
    class StreamManager
    {
        public
        let session:Session

        @usableFromInline
        var cursor:CursorIdentifier

        public
        let namespace:Namespace
        public
        let batching:Int
        public
        let timeout:Mongo.Milliseconds?

        public
        init?(session:Session, cursor:CursorIdentifier,
            namespace:Namespace,
            batching:Int,
            timeout:Mongo.Milliseconds?)
        {
            self.session = session
            self.cursor = cursor

            guard self.cursor != .none
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
            guard self.cursor != .none
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
    @inlinable public
    var database:Mongo.Database
    {
        self.namespace.database
    }
    @inlinable public
    var collection:Mongo.Collection
    {
        self.namespace.collection
    }
    @inlinable public
    func get<Element>(more _:Element.Type) async throws -> [Element]?
        where Element:MongoDecodable
    {
        guard   let command:Mongo.GetMore<Element> = .init(cursor: self.cursor,
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
