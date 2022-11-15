import BSONDecoding
import NIOCore

// public struct MongoCursorResponse: Decodable, Sendable {
//     public struct Cursor: Codable, Sendable {
//         private enum CodingKeys: String, CodingKey {
//             case id, firstBatch
//             case namespace = "ns"
//         }
        
//         public var id: Int64
//         public var namespace: String
//         public var firstBatch: [Document]
        
//         public init(id: Int64, namespace: String, firstBatch: [Document]) {
//             self.id = id
//             self.namespace = namespace
//             self.firstBatch = firstBatch
//         }
//     }
    
//     public let cursor: Cursor
//     public let ok: Int
// }
extension Mongo
{
    @frozen public
    struct Cursor:Identifiable
    {
        public
        let id:Int64
        // TODO: replace with ``Namespace``
        public
        let namespace:String
        public
        let documents:[BSON.Document<ByteBufferView>]

        @inlinable public
        init(id:Int64, namespace:String, documents:[BSON.Document<ByteBufferView>])
        {
            self.id = id
            self.namespace = namespace
            self.documents = documents
        }
    }
}
extension Mongo.Cursor:MongoResponse
{
    public
    init(from dictionary:BSON.Dictionary<ByteBufferView>) throws
    {
        self = try dictionary["cursor"].decode(as: BSON.Dictionary<ByteBufferView>.self)
        {
            .init(id: try $0["id"].decode(to: Int64.self),
                namespace: try $0["ns"].decode(as: String.self)
                {
                    $0
                },
                documents: try $0["firstBatch"].decode(as: BSON.Array<ByteBufferView>.self)
                {
                    try $0.map { try $0.decode(to: BSON.Document<ByteBufferView>.self) }
                })
        }
    }
}
