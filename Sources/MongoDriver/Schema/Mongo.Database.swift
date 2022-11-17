import BSONDecoding
import NIOCore

extension Mongo
{
    /// Information about a MongoDB database.
    @frozen public
    struct Database:Identifiable
    {
        public
        let id:ID
        /// The size of this database on disk, in bytes.
        /// This is called `sizeOnDisk` in the server response.
        public
        let size:Int

        @inlinable public
        init(id:ID, size:Int)
        {
            self.id = id
            self.size = size
        }
    }
}
extension Mongo.Database
{
    @inlinable public
    var name:String
    {
        self.id.name
    }
}
extension Mongo.Database:MongoScheme
{
    public
    init(bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self.init(id: try bson["name"].decode(as: String.self, with: ID.init(_:)),
            size: try bson["sizeOnDisk"].decode(to: Int.self))
    }
}
