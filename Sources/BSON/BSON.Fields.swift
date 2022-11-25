extension BSON
{
    @frozen public
    struct Fields:Sendable
    {
        public
        var output:BSON.Output<[UInt8]>

        @inlinable public
        init(output:BSON.Output<[UInt8]> = .init(capacity: 0))
        {
            self.output = output
        }
    }
}
extension BSON.Fields
{
    /// Creates a document containing the given fields.
    /// The order of the fields will be preserved.
    @inlinable public
    init(_ fields:some Collection<(key:String, value:BSON.Value<some RandomAccessCollection<UInt8>>)>)
    {
        self.init(output: .init(fields: fields))
    }
}
// extension BSON.Fields:ExpressibleByDictionaryLiteral
// {
//     @inlinable public
//     init(dictionaryLiteral:(String, BSON.Value<[UInt8]>)...)
//     {
//         self.init(dictionaryLiteral)
//     }
// }
extension BSON.Fields
{
    /// Appends the given (array-backed) key-value pair to this document builder
    /// as a field if the value is not [`nil`](), does nothing otherwise. The
    /// getter always returns [`nil`]().
    ///
    /// Every non-[`nil`]() assignment to this subscript (including mutations
    /// that leave the value in a non-[`nil`]() state after returning) will add
    /// a new field to the document intermediate, even if the key is the same.
    @inlinable public
    subscript(key:String) -> BSON.Value<[UInt8]>?
    {
        get
        {
            nil
        }
        set(value)
        {
            if let value:BSON.Value<[UInt8]>
            {
                self.output.serialize(key: key, value: value)
            }
        }
    }
    /// Appends the given key-value pair to this document builder as a field
    /// if the value is not [`nil`](), does nothing otherwise. The getter
    /// always returns [`nil`]().
    ///
    /// Every non-[`nil`]() assignment to this subscript (including mutations
    /// that leave the value in a non-[`nil`]() state after returning) will add
    /// a new field to the document intermediate, even if the key is the same.
    @inlinable public
    subscript<Bytes>(key:String) -> BSON.Value<Bytes>?
    {
        get
        {
            nil
        }
        set(value)
        {
            if let value:BSON.Value<Bytes>
            {
                self.output.serialize(key: key, value: value)
            }
        }
    }
}
