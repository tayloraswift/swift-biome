import BSONTraversal

infix operator ~~ : ComparisonPrecedence

extension BSON
{
    @frozen public
    enum DocumentFrame:VariableLengthBSONFrame
    {
        public static
        let prefix:Int = 4
        public static
        let suffix:Int = 1
    }
    /// A BSON document. The backing storage of this type is opaque,
    /// permitting lazy parsing of its inline content.
    @frozen public
    struct Document<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        /// The raw data backing this document. This collection *does not*
        /// include the trailing null byte that typically appears after its
        /// inline fields list.
        public 
        let bytes:Bytes

        /// Stores the argument in ``bytes`` unchanged.
        ///
        /// >   Complexity: O(1)
        @inlinable public
        init(bytes:Bytes)
        {
            self.bytes = bytes
        }
    }
}
extension BSON.Document:Equatable
{
    /// Performs an exact byte-wise comparison on two tuples.
    /// Does not parse or validate the operands.
    @inlinable public static
    func == (lhs:Self, rhs:BSON.Document<some RandomAccessCollection<UInt8>>) -> Bool
    {
        lhs.bytes.elementsEqual(rhs.bytes)
    }
}
extension BSON.Document:Sendable where Bytes:Sendable
{
}
extension BSON.Document:VariableLengthBSON
{
    public
    typealias Frame = BSON.DocumentFrame
    
    /// Stores the argument in ``bytes`` unchanged. Equivalent to ``init(bytes:)``.
    ///
    /// >   Complexity: O(1)
    @inlinable public
    init(slicing bytes:Bytes)
    {
        self.init(bytes: bytes)
    }
}

extension BSON.Document
{
    /// Splits this document’s inline key-value pairs into an array.
    ///
    /// >   Complexity: O(*n*), where *n* is the size of this document’s backing storage.
    @inlinable public
    func parse() throws -> [(key:String, value:BSON.Value<Bytes.SubSequence>)]
    {
        var input:BSON.Input<Bytes> = .init(self.bytes)
        var items:[(key:String, value:BSON.Value<Bytes.SubSequence>)] = []
        while let code:UInt8 = input.next()
        {
            let type:BSON = try .init(code: code)
            let key:String = try input.parse(as: String.self)
            items.append((key, try input.parse(variant: type)))
        }
        return items
    }
}
extension BSON.Document
{
    /// The length that would be encoded in this document’s prefixed header.
    /// Equal to [`self.size`]().
    @inlinable public
    var header:Int32
    {
        .init(self.size)
    }
    
    /// The size of this document when encoded with its header and trailing null byte.
    /// This *is* the same as the length encoded in the header itself.
    @inlinable public
    var size:Int
    {
        5 + self.bytes.count
    }
}

extension BSON.Document<[UInt8]>
{
    /// Stores the output buffer of the given document fields into
    /// an instance of this type.
    ///
    /// >   Complexity: O(1).
    @inlinable public
    init(_ fields:BSON.Fields)
    {
        self.init(bytes: fields.output.destination)
    }
}

extension BSON.Document:ExpressibleByDictionaryLiteral 
    where Bytes:RangeReplaceableCollection<UInt8>
{
    /// Creates a document containing the given fields.
    /// The order of the fields will be preserved.
    @inlinable public
    init(_ fields:some Collection<(key:String, value:BSON.Value<some RandomAccessCollection<UInt8>>)>)
    {
        self.init(bytes: BSON.Output<Bytes>.init(fields: fields).destination)
    }

    /// Creates a document containing a single key-value pair.
    @inlinable public
    init<Other>(key:String, value:BSON.Value<Other>)
        where Other:RandomAccessCollection<UInt8>
    {
        self.init(CollectionOfOne<(key:String, value:BSON.Value<Other>)>.init((key, value)))
    }

    @inlinable public
    init(dictionaryLiteral:(String, BSON.Value<Bytes>)...)
    {
        self.init(dictionaryLiteral)
    }
    /// Recursively parses and re-encodes this document, and any embedded documents
    /// (and tuple-documents) in its elements. The keys will not be changed or re-ordered.
    @inlinable public
    func canonicalized() throws -> Self
    {
        .init(try self.parse().map { ($0.key, try $0.value.canonicalized()) })
    }
}

extension BSON.Document:CustomStringConvertible
{
    public
    var description:String
    {
        """
        (\(self.header), \(self.bytes.lazy.map 
        {
            """
            \(String.init($0 >> 4,   radix: 16, uppercase: true))\
            \(String.init($0 & 0x0f, radix: 16, uppercase: true))
            """
        }.joined(separator: "_")))
        """
    }
}
extension BSON.Document
{
    /// Performs a type-aware equivalence comparison by parsing each operand and recursively
    /// comparing the elements. Returns [`false`]() if either operand fails to parse.
    ///
    /// Some documents that do not compare equal under byte-wise
    /// `==` comparison may compare equal under this operator, due to normalization
    /// of deprecated BSON variants. For example, a value of the deprecated `symbol` type
    /// will compare equal to a `BSON//Value.string(_:)` value with the same contents.
    @inlinable public static
    func ~~ <Other>(lhs:Self, rhs:BSON.Document<Other>) -> Bool
    {
        if  let lhs:[(key:String, value:BSON.Value<Bytes.SubSequence>)] = try? lhs.parse(),
            let rhs:[(key:String, value:BSON.Value<Other.SubSequence>)] = try? rhs.parse(),
                rhs.count == lhs.count
        {
            for (lhs, rhs):
            (
                (key:String, value:BSON.Value<Bytes.SubSequence>),
                (key:String, value:BSON.Value<Other.SubSequence>)
            )
            in zip(lhs, rhs)
            {
                guard   lhs.key   ==  rhs.key,
                        lhs.value ~~ rhs.value
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
