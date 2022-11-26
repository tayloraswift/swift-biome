import MongoSchema

extension Mongo
{
    @frozen public
    struct Stream<BatchElement> where BatchElement:MongoDecodable
    {
        @usableFromInline private(set)
        var manager:StreamManager?
        @usableFromInline private(set)
        var first:[BatchElement]?

        @inlinable public
        init(manager:StreamManager?, first:[BatchElement])
        {
            self.manager = manager
            self.first = first
        }
    }
}
extension Mongo.Stream:AsyncSequence, AsyncIteratorProtocol
{
    public
    typealias Element = [BatchElement]

    @inlinable public
    func makeAsyncIterator() -> Self
    {
        self
    }
    @inlinable public mutating
    func next() async throws -> [BatchElement]?
    {
        if  let first:[BatchElement] = self.first
        {
            self.first = nil
            return first
        }
        guard let manager:Mongo.StreamManager = self.manager
        else
        {
            return nil
        }
        guard let batch:[BatchElement] = try await manager.get(more: BatchElement.self)
        else
        {
            self.manager = nil
            return nil
        }
        if manager.cursor == .none
        {
            self.manager = nil
        }
        
        return batch
    }
}

extension Mongo.Session
{
    @inlinable public
    func run<Query>(query:Query, 
        against database:Mongo.Database) async throws -> Mongo.Stream<Query.Element>
        where Query:MongoStreamableCommand
    {
        let batching:Int = query.batching
        let timeout:Mongo.Milliseconds? = query.timeout
        let cursor:Mongo.Cursor<Query.Element> = try await self.run(command: query,
            against: database)
        return .init(manager: .init(session: self, cursor: cursor.id,
                namespace: cursor.namespace,
                batching: batching,
                timeout: timeout),
            first: cursor.elements)
    }
}
