import BSON

extension BSON.Tuple:CollectionViewBSON
{
    @inlinable public
    init(_ value:BSON.Value<Bytes>) throws
    {
        self = try value.cast(with: \.tuple)
    }
}
