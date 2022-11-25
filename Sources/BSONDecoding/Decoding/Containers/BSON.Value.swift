extension BSON.Value
{
    /// Attempts to unwrap and parse an array-decoder from this variant.
    ///
    /// This method will only attempt to parse statically-typed BSON tuples; it will not
    /// inspect general documents to determine if they are valid tuples.
    /// 
    /// -   Returns:
    ///     The payload of this variant, parsed to an array-decoder, if it matches
    ///     ``case tuple(_:)`` and could be successfully parsed, [`nil`]() otherwise.
    ///
    /// To get a plain array with no decoding interface, cast this variant to
    /// a ``BSON/Tuple`` and call its ``BSON/Tuple/.parse()`` method. Alternatively,
    /// you can use this method and access the ``BSON//Array.elements`` property.
    ///
    /// >   Complexity: 
    //      O(*n*), where *n* is the number of elements in the source tuple.
    @inlinable public 
    func array() throws -> BSON.Array<Bytes.SubSequence>
    {
        .init(try BSON.Tuple<Bytes>.init(self).parse())
    }
    /// Attempts to unwrap and parse a fixed-length array-decoder from this variant.
    /// 
    /// -   Returns:
    ///     The payload of this variant, parsed to an array-decoder, if it matches
    ///     ``case tuple(_:)``, could be successfully parsed, and contains the
    ///     expected number of elements.
    ///
    /// >   Throws:
    ///     An ``ArrayShapeError`` if an array was successfully unwrapped and 
    ///     parsed, but it did not contain the expected number of elements.
    @inlinable public 
    func array(count:Int) throws -> BSON.Array<Bytes.SubSequence>
    {
        let array:BSON.Array<Bytes.SubSequence> = try self.array()
        if  array.count == count 
        {
            return array
        }
        else 
        {
            throw BSON.ArrayShapeError.init(count: array.count, expected: count)
        }
    }

    /// Attempts to unwrap and parse an array-decoder from this variant, whose length 
    /// satifies the given criteria.
    /// 
    /// -   Returns:
    ///     The payload of this variant if it matches ``case tuple(_:)``, could be
    ///     successfully parsed, and contains the expected number of elements.
    ///
    /// >   Throws:
    ///     An ``ArrayShapeError`` if an array was successfully unwrapped and 
    ///     parsed, but it did not contain the expected number of elements.
    @inlinable public 
    func array(
        where predicate:(_ count:Int) throws -> Bool) throws -> BSON.Array<Bytes.SubSequence>
    {
        let array:BSON.Array<Bytes.SubSequence> = try self.array()
        if try predicate(array.count)
        {
            return array
        }
        else 
        {
            throw BSON.ArrayShapeError.init(count: array.count)
        }
    }
}
extension BSON.Value
{
    /// Attempts to load a dictionary-decoder from this variant.
    /// 
    /// - Returns: A dictionary-decoder derived from the payload of this variant if it 
    ///     matches ``case document(_:)`` or ``case tuple(_:)``, [`nil`]() otherwise.
    ///
    /// This method will throw a ``BSON//DictionaryKeyError`` more than one document
    /// field contains a key with the same name.
    ///
    /// Key duplication can interact with unicode normalization in unexpected 
    /// ways. Because BSON is defined in UTF-8, other BSON encoders may not align 
    /// with the behavior of ``String.==(_:_:)``, since that operator 
    /// compares grapheme clusters and not UTF-8 code units. 
    /// 
    /// For example, if a document vends separate keys for [`"\u{E9}"`]() ([`"é"`]()) and 
    /// [`"\u{65}\u{301}"`]() (also [`"é"`](), perhaps, because the document is 
    /// being used to bootstrap a unicode table), uniquing them by ``String`` 
    /// comparison would drop one of the values.
    ///
    /// To get a plain array of key-value pairs with no decoding interface, cast this
    /// variant to a ``BSON/Document`` and call its ``BSON/Document/.parse()`` method.
    /// 
    /// >   Complexity: 
    ///     O(*n*), where *n* is the number of fields in the source document.
    ///
    /// >   Warning: 
    ///     When you convert an object to a dictionary representation, you lose the ordering 
    ///     information for the object items. Reencoding it may produce a BSON 
    ///     document that contains the same data, but does not compare equal.
    @inlinable public 
    func dictionary() throws -> BSON.Dictionary<Bytes.SubSequence>
    {
        try .init(fields: try BSON.Document<Bytes>.init(self).parse())
    }
}
