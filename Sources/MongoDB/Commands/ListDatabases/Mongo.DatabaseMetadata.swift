import BSONDecoding

extension Mongo
{
    /// Information about a MongoDB database.
    @frozen public
    struct DatabaseMetadata:Sendable
    {
        public
        let database:Database
        /// The size of this database on disk, in bytes.
        /// This is called `sizeOnDisk` in the server response.
        public
        let size:Int

        @inlinable public
        init(database:Database, size:Int)
        {
            self.database = database
            self.size = size
        }
    }
}
extension Mongo.DatabaseMetadata:BSONDictionaryDecodable
{
    @inlinable public
    init(bson:BSON.Dictionary<some RandomAccessCollection<UInt8>>) throws
    {
        self.init(database: try bson["name"].decode(to: Mongo.Database.self),
            size: try bson["sizeOnDisk"].decode(to: Int.self))
    }
}
