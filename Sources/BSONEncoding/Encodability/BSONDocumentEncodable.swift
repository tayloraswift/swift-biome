public
protocol BSONDocumentEncodable:BSONEncodable
{
    func encode(to:inout BSON.Fields)
}
extension BSONDocumentEncodable
{
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .document(.init(self.encode(to:)))
    }
}
