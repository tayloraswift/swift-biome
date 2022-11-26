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
    subscript<Encodable>(key:String) -> Encodable?
        where Encodable:BSONEncodable
    {
        get
        {
            nil
        }
        set(value)
        {
            if let value:Encodable
            {
                self.output.serialize(key: key, value: value.bson)
            }
        }
    }
    @inlinable public
    subscript<View>(key:String) -> View?
        where View:CollectionViewBSON
    {
        get
        {
            nil
        }
        set(value)
        {
            if let value:View
            {
                self.output.serialize(key: key, value: value.bson)
            }
        }
    }
    @inlinable public
    subscript(key:String) -> Void?
    {
        get
        {
            nil
        }
        set(value)
        {
            if let _:Void = value
            {
                self.output.serialize(key: key, value: BSON.Value<[UInt8]>.null)
            }
        }
    }
}
extension BSON.Fields
{
    /// Appends the given key-value pair to this document builder as a field
    /// by accessing the value’s ``BSONEncodable.bson`` property witness, if
    /// it is not [`nil`]() and is not empty (or `elide` is [`false`]()), does
    /// nothing otherwise. The getter always returns [`nil`]().
    ///
    /// Every non-[`nil`]() assignment to this subscript (including mutations
    /// that leave the value in a non-[`nil`]() state after returning) will add
    /// a new field to the document intermediate, even if the key is the same.
    @inlinable public
    subscript<Encodable>(key:String, elide elide:Bool) -> Encodable?
        where Encodable:BSONEncodable & Collection
    {
        get
        {
            nil
        }
        set(value)
        {
            if let value:Encodable, !(elide && value.isEmpty)
            {
                self.output.serialize(key: key, value: value.bson)
            }
        }
    }
    @inlinable public
    subscript(key:String, elide elide:Bool = false) -> Self?
    {
        get
        {
            nil
        }
        set(value)
        {
            if let value:Self, !(elide && value.isEmpty)
            {
                self.output.serialize(key: key, value: value.bson)
            }
        }
    }
}
