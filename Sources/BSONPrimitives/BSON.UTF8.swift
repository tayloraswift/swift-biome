import BSON

extension BSON.UTF8:CollectionViewBSON
{
    @inlinable public
    init(_ value:BSON.Value<Bytes>) throws
    {
        self = try value.cast(with: \.utf8)
    }
}
