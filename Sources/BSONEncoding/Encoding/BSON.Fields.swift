extension BSON.Fields
{
    /// Appends the given key-value pair to this document builder as a field
    /// by accessing the value’s ``BSONEncodable.bson`` property witness, if
    /// it is not [`nil`](), does nothing otherwise. The getter always returns
    /// [`nil`]().
    ///
    /// Every non-[`nil`]() assignment to this subscript (including mutations
    /// that leave the value in a non-[`nil`]() state after returning) will add
    /// a new field to the document intermediate, even if the key is the same.
    @inlinable public
    subscript<Encodable>(key:String) -> Encodable? where Encodable:BSONEncodable
    {
        get
        {
            nil
        }
        set(value)
        {
            self[key] = value?.bson
        }
    }
}
