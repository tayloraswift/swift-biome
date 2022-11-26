import BSON

extension BSON.Document:CollectionViewBSON
{
    @inlinable public
    init(_ value:BSON.Value<Bytes>) throws
    {
        self = try value.cast(with: \.document)
    }
    @inlinable public
    var bson:BSON.Value<Bytes>
    {
        .document(self)
    }
}
