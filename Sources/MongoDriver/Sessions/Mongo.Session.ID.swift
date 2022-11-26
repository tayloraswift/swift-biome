import BSONSchema
import UUID

extension Mongo.Session
{
    public 
    struct ID:Hashable, Sendable 
    {
        public
        let uuid:UUID

        @inlinable public
        init(_ uuid:UUID) 
        {
            self.uuid = uuid
        }
    }
}
extension Mongo.Session.ID
{
    static
    func random() -> Self
    {
        .init(.random())
    }
}

extension Mongo.Session.ID:BSONDictionaryDecodable, BSONDocumentEncodable
{
    @inlinable public
    init<Bytes>(bson:BSON.Dictionary<Bytes>) throws
    {
        self.init(try bson["id"].decode(as: BSON.Binary<Bytes>.self)
        {
            UUID.init($0.bytes)
        })
    }
    @inlinable public
    func encode(to bson:inout BSON.Fields)
    {
        bson["id"] = BSON.Binary<UUID>.init(subtype: .uuid, bytes: self.uuid)
    }
}
