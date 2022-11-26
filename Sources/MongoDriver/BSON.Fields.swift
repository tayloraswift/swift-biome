import BSONEncoding

extension BSON.Fields
{
    /// Adds a MongoDB database identifier to this list of fields, under the key [`"$db"`]().
    mutating
    func add(database:Mongo.Database)
    {
        self["$db"] = database
    }
}
extension BSON.Fields
{
    /// Adds a MongoDB session identifier to this list of fields, under the key [`"lsid"`]().
    mutating
    func add(session:Mongo.Session.ID)
    {
        self["lsid"] = session
    }
}
