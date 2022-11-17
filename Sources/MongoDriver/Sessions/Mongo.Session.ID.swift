import BSONEncoding
import UUID

extension Mongo.Session
{
    public 
    struct ID:Hashable, Sendable 
    {
        let uuid:UUID

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

extension BSON.Fields where Bytes:RangeReplaceableCollection
{
    /// Adds a MongoDB session identifier to this list of fields, under the key [`"lsid"`]().
    mutating
    func add(session:Mongo.Session.ID)
    {
        let binary:BSON.Binary<UUID> = .init(subtype: .uuid, bytes: session.uuid[...])
        self.add(key: "lsid", value: .document(.init(key: "id", value: .binary(binary))))
    }
}
