extension Array
{
    /// Decodes the element at the specified index with the given decoder. Throws a
    /// ``BSON/RecursiveError.tuple(_:at:)`` wrapping the underlying error if decoding
    /// fails.
    @inlinable public
    func decode<Bytes, T>(_ index:Int, with decode:(Element) throws -> T) throws -> T
        where Element == BSON.Variant<Bytes>
    {
        do
        {
            return try decode(self[index])
        }
        catch let error 
        {
            throw BSON.RecursiveError.tuple(error, at: index)
        }
    }
}
