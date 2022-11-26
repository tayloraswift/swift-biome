public
protocol BSONDocumentEncodable:BSONEncodable
{
    /// Creates a document from this instance by writing its
    /// fields to the encoding view parameter. The implementation
    /// may assume the encoding view is initially empty.
    func encode(to:inout BSON.Fields)
}
extension BSONDocumentEncodable
{
    @inlinable public
    var bson:BSON.Value<[UInt8]>
    {
        .document(.init(.init(with: self.encode(to:))))
    }
}
