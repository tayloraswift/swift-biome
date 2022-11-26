import BSONEncoding

extension Mongo
{
    @frozen public
    enum IndexHint:Sendable
    {
        case id(String)
        case index(BSON.Document<[UInt8]>)
    }
}
extension Mongo.IndexHint:BSONEncodable
{
    public
    var bson:BSON.Value<[UInt8]>
    {
        switch self
        {
        case .id(let string):       return .string(string)
        case .index(let document):  return .document(document)
        }
    }
}
