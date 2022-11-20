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
