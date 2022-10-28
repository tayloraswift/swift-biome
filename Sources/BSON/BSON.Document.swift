import BSONTraversal

infix operator =~= : ComparisonPrecedence

extension BSON
{
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
extension BSON.Document:Equatable where Bytes:Equatable
{
}
extension BSON.Document:Sendable where Bytes:Sendable
{
}
extension BSON.Document:TraversableBSON
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
    /// Upcasts a BSON array to a document.
    ///
    /// >   Complexity: O(1)
    @inlinable public
    init(_ array:BSON.Array<Bytes>)
    {
        self.init(array.bytes)
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
                break
            }
        }
        try input.finish()
        return items
    }
}
extension BSON.Document where Bytes:RangeReplaceableCollection<UInt8>
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
        assert(output.destination.count == size)
        self.init(output.destination)
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
        Self.headerSize + self.bytes.count
    }
}
extension BSON.Document:ExpressibleByDictionaryLiteral 
    where Bytes:RangeReplaceableCollection<UInt8>
{
    @inlinable public
    init(dictionaryLiteral:(String, BSON.Variant<Bytes>)...)
    {
        self.init(dictionaryLiteral)
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
extension BSON.Document where Bytes.SubSequence:Equatable
{
    @inlinable public static
    func =~= (lhs:Self, rhs:Self) -> Bool
    {
        if  let lhs:[(key:String, value:BSON.Variant<Bytes.SubSequence>)] = try? lhs.parse(),
            let rhs:[(key:String, value:BSON.Variant<Bytes.SubSequence>)] = try? rhs.parse(),
                rhs.count == lhs.count
        {
            for (lhs, rhs):
            (
                (key:String, value:BSON.Variant<Bytes.SubSequence>),
                (key:String, value:BSON.Variant<Bytes.SubSequence>)
            )
            in zip(lhs, rhs)
            {
                guard   lhs.key   ==  rhs.key,
                        lhs.value =~= rhs.value
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
