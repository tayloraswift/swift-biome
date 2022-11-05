import BSONTraversal

infix operator ~~ : ComparisonPrecedence

extension BSON
{
    @frozen public
    enum DocumentHeader:TraversableBSONHeader
    {
        public static
        let size:Int = 4
    }
    /// A BSON document. The backing storage of this type is opaque,
    /// permitting lazy parsing of its inline content.
    @frozen public
    struct Document<Bytes> where Bytes:RandomAccessCollection<UInt8>
    {
        /// The raw data backing this document. This collection *does*
        /// include the trailing null byte that appears after its inline 
        /// elements list.
        public 
        let bytes:Bytes

        @inlinable public
        init(_ bytes:Bytes)
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
extension BSON.Document:TraversableBSON
{
    public
    typealias Header = BSON.DocumentHeader
    /// Stores the argument in ``bytes`` unchanged.
    ///
    /// >   Complexity: O(1)
    @inlinable public
    init(slicing bytes:Bytes)
    {
        self.init(bytes)
    }
}

extension BSON.Document
{
    /// Splits this document’s inline key-value pairs into an array.
    ///
    /// >   Complexity: O(*n*), where *n* is the size of this document’s backing storage.
    @inlinable public
    func parse() throws -> [(key:String, value:BSON.Variant<Bytes.SubSequence>)]
    {
        var input:BSON.Input<Bytes> = .init(self.bytes)
        var items:[(key:String, value:BSON.Variant<Bytes.SubSequence>)] = []
        while let code:UInt8 = input.next()
        {
            if code != 0x00
            {
                let key:String = try input.parse(as: String.self)
                items.append((key, try input.parse(variant: try .init(code: code))))
            }
            else
            {
                try input.finish()
                return items
            }
        }
        throw BSON.InputError.init(expected: .bytes(1))
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
    
    /// The size of this document when encoded with its header.
    /// This *is* the same as the length encoded in the header itself.
    @inlinable public
    var size:Int
    {
        Header.size + self.bytes.count
    }
}
extension BSON.Document:ExpressibleByDictionaryLiteral 
    where Bytes:RangeReplaceableCollection<UInt8>
{
    @inlinable public
    init<Other>(_ items:some Collection<(key:String, value:BSON.Variant<Other>)>)
        where Other:RandomAccessCollection<UInt8>
    {
        let size:Int = items.reduce(1) { $0 + 2 + $1.key.utf8.count + $1.value.size }
        var output:BSON.Output<Bytes> = .init(capacity: size)
        // do *not* emit the length header!
        for (key, value):(String, BSON.Variant<Other>) in items
        {
            output.append(value.type.rawValue)
            output.serialize(cString: key)
            output.serialize(variant: value)
        }
        output.append(0x00)
        assert(output.destination.count == size,
            "precomputed size (\(size)) does not match output size (\(output.destination.count))")
        self.init(output.destination)
    }

    @inlinable public
    init(dictionaryLiteral:(String, BSON.Variant<Bytes>)...)
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
    /// will compare equal to a `BSON//Variant.string(_:)` value with the same contents.
    @inlinable public static
    func ~~ <Other>(lhs:Self, rhs:BSON.Document<Other>) -> Bool
    {
        if  let lhs:[(key:String, value:BSON.Variant<Bytes.SubSequence>)] = try? lhs.parse(),
            let rhs:[(key:String, value:BSON.Variant<Other.SubSequence>)] = try? rhs.parse(),
                rhs.count == lhs.count
        {
            for (lhs, rhs):
            (
                (key:String, value:BSON.Variant<Bytes.SubSequence>),
                (key:String, value:BSON.Variant<Other.SubSequence>)
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
