import BSON

extension BSON.Binary:CollectionViewBSON
{
    @inlinable public
    init(_ value:BSON.Value<Bytes>) throws
    {
        self = try value.cast(with: \.binary)
    }
    @inlinable public
    var bson:BSON.Value<Bytes>
    {
        .binary(self)
    }
}
