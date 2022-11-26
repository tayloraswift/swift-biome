import BSONDecoding

extension Mongo
{
    @frozen public
    struct Cursor<Element>:Sendable, Identifiable
        where Element:BSONDocumentDecodable & Sendable
    {
        public
        let id:CursorIdentifier
        public
        let namespace:Namespace
        public
        let elements:[Element]

        @inlinable public
        init(id:CursorIdentifier, namespace:Namespace, elements:[Element])
        {
            self.id = id
            self.namespace = namespace
            self.elements = elements
        }
    }
}
extension Mongo.Cursor
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
}
extension Mongo.Cursor:Equatable where Element:Equatable
{
}
extension Mongo.Cursor:BSONDictionaryDecodable
{
    @inlinable public
    init<Bytes>(bson:BSON.Dictionary<Bytes>) throws
    {
        self = try bson["cursor"].decode(as: BSON.Dictionary<Bytes.SubSequence>.self)
        {
            .init(id: try $0["id"].decode(to: Mongo.CursorIdentifier.self),
                namespace: try $0["ns"].decode(to: Mongo.Namespace.self),
                elements: try ($0["firstBatch"] ?? $0["nextBatch"]).decode(to: [Element].self))
        }
    }
}
