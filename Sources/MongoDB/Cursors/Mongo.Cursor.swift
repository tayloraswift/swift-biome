import BSONDecoding
import NIOCore

extension Mongo
{
    @frozen public
    struct Cursor<Element>:Sendable, Identifiable where Element:MongoDecodable
    {
        public
        let id:Int64
        public
        let namespace:Namespace
        public
        let elements:[Element]

        @inlinable public
        init(id:Int64, namespace:Namespace, elements:[Element])
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
    var database:Mongo.Database.ID
    {
        self.namespace.database
    }
    @inlinable public
    var collection:Mongo.Collection.ID
    {
        self.namespace.collection
    }
}
extension Mongo.Cursor:Equatable where Element:Equatable
{
}
extension Mongo.Cursor:MongoDecodable
{
    @inlinable public
    init(bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self = try bson["cursor"].decode(as: BSON.Dictionary<ByteBufferView>.self)
        {
            return .init(id: try $0["id"].decode(to: Int64.self),
                namespace: try $0["ns"].decode(as: String.self,
                    with: Mongo.Namespace.init(parsing:)),
                elements: try ($0["firstBatch"] ?? $0["nextBatch"]).decode(
                    as: BSON.Array<ByteBufferView>.self)
                {
                    try $0.map
                    {
                        try $0.decode(as: BSON.Document<ByteBufferView>.self,
                            with: Element.init(bson:))
                    }
                })
        }
    }
}
