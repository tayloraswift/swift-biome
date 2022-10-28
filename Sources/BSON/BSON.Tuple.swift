import BSONTraversal

extension BSON
{
    /// A BSON tuple. The backing storage of this type is opaque,
    /// permitting lazy parsing of its inline content.
    @frozen public
    struct Tuple<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        public
        let document:BSON.Document<Bytes>

        @inlinable public
        init(_ bytes:Bytes)
        {
            self.document = .init(bytes)
        }
    }
}
extension BSON.Tuple:Equatable
{
    /// Performs an exact byte-wise comparison on two tuples.
    /// Does not parse or validate the operands.
    @inlinable public static
    func == (lhs:Self, rhs:BSON.Tuple<some RandomAccessCollection<UInt8>>) -> Bool
    {
        lhs.document == rhs.document
    }
}
extension BSON.Tuple:Sendable where Bytes:Sendable
{
}
extension BSON.Tuple:TraversableBSON
{
    @inlinable public static
    var headerSize:Int
    {
        4
    }
    /// Stores the argument in ``bytes`` unchanged.
    ///
    /// >   Complexity: O(1)
    @inlinable public
    init(slicing bytes:Bytes)
    {
        self.init(bytes)
    }
}
extension BSON.Tuple
{
    /// The raw data backing this tuple. This collection *does*
    /// include the trailing null byte that appears after its inline 
    /// elements list.
    @inlinable public
    var bytes:Bytes
    {
        self.document.bytes
    }
    /// The length that would be encoded in this tuple’s prefixed header.
    /// Equal to [`self.size`]().
    @inlinable public
    var header:Int32
    {
        .init(self.size)
    }

    /// The size of this tuple when encoded with its header.
    /// This *is* the same as the length encoded in the header itself.
    @inlinable public
    var size:Int
    {
        Self.headerSize + self.bytes.count
    }
}

extension BSON.Tuple
{
    /// Splits this tuple’s inline key-value pairs into an array containing the
    /// values only. Parsing a tuple is slightly faster than parsing a general 
    /// ``Document``, because this method ignores the document keys.
    ///
    /// This method does *not* perform any key validation.
    ///
    /// >   Complexity: O(*n*), where *n* is the size of this tuple’s backing storage.
    @inlinable public
    func parse() throws -> [BSON.Variant<Bytes.SubSequence>]
    {
        var input:BSON.Input<Bytes> = .init(self.bytes)
        var elements:[BSON.Variant<Bytes.SubSequence>] = []
        while let code:UInt8 = input.next()
        {
            if code != 0x00
            {
                try input.parse(through: 0x00)
                elements.append(try input.parse(variant: try .init(code: code)))
            }
            else
            {
                try input.finish()
                return elements
            }
        }
        throw BSON.EndOfInputError.unexpected
    }
}
extension BSON.Tuple:ExpressibleByArrayLiteral
    where Bytes:RangeReplaceableCollection<UInt8>
{
    @inlinable public 
    init(_ elements:some Sequence<BSON.Variant<some RandomAccessCollection<UInt8>>>)
    {
        // we do need to precompute the ordinal keys, so we know the total length
        // of the document.
        let document:BSON.Document<Bytes> = .init(elements.enumerated().map
        {
            ($0.0.description, $0.1)
        })
        self.init(document.bytes)
    }

    @inlinable public 
    init(arrayLiteral:BSON.Variant<Bytes>...)
    {
        self.init(arrayLiteral)
    }

    /// Recursively parses and re-encodes this tuple-document, and any embedded documents
    /// (and tuple-documents) in its elements. The ordinal keys will be regenerated.
    @inlinable public
    func canonicalized() throws -> Self
    {
        .init(try self.parse().map { try $0.canonicalized() })
    }
}
extension BSON.Tuple
{
    /// Performs a “canonical” comparison by parsing each operand and recursively
    /// comparing the elements, ignoring tuple key names. Returns [`false`]() if either
    /// operand fails to parse.
    ///
    /// Some embedded documents that do not compare equal under byte-wise
    /// `==` comparison may also compare equal under this operator, due to normalization
    /// of deprecated BSON variants. For example, a value of the deprecated `symbol` type
    /// will compare equal to a `BSON//Variant.string(_:)` value with the same contents.
    @inlinable public static
    func ~~ <Other>(lhs:Self, rhs:BSON.Tuple<Other>) -> Bool
    {
        if  let lhs:[BSON.Variant<Bytes.SubSequence>] = try? lhs.parse(),
            let rhs:[BSON.Variant<Other.SubSequence>] = try? rhs.parse(),
                rhs.count == lhs.count
        {
            for (lhs, rhs):(BSON.Variant<Bytes.SubSequence>, BSON.Variant<Other.SubSequence>) in
                zip(lhs, rhs)
            {
                guard lhs ~~ rhs
                else
                {
                    return false
                }
            }
            return true
        }
        else
        {
            return false
        }
    }
}
