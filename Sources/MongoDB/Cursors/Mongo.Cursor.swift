import BSONDecoding
import NIOCore

extension Mongo
{
    @frozen public
    struct Cursor<Element>:Identifiable where Element:MongoDecodable
    {
        public
        let id:Int64
        // TODO: replace with ``Namespace``
        public
        let namespace:String
        public
        let documents:[Element]

        @inlinable public
        init(id:Int64, namespace:String, documents:[Element])
        {
            self.id = id
            self.namespace = namespace
            self.documents = documents
        }
    }
}
extension Mongo.Cursor:MongoScheme
{
    @inlinable public
    init(bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self = try bson["cursor"].decode(as: BSON.Dictionary<ByteBufferView>.self)
        {
            .init(id: try $0["id"].decode(to: Int64.self),
                namespace: try $0["ns"].decode(as: String.self)
                {
                    $0
                },
                documents: try $0["firstBatch"].decode(as: BSON.Array<ByteBufferView>.self)
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
