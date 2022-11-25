import BSONTraversal

extension BSON
{
    @frozen public
    struct Output<Destination> where Destination:RangeReplaceableCollection<UInt8>
    {
        public
        var destination:Destination

        /// Create an output with a pre-allocated destination buffer. The buffer
        /// does *not* need to be empty, and existing data will not be cleared.
        @inlinable public
        init(preallocated destination:Destination)
        {
            self.destination = destination
        }

        /// Create an empty output, reserving enough space for the specified
        /// number of bytes in the destination buffer.
        ///
        /// The size hint is only effective if `Destination` provides a real,
        /// non-defaulted witness for ``RangeReplaceableCollection.reserveCapacity(_:)``.
        @inlinable public
        init(capacity:Int)
        {
            self.destination = .init()
            self.destination.reserveCapacity(capacity)
        }
    }
}
extension BSON.Output:Sendable where Destination:Sendable
{
}
extension BSON.Output
{
    /// Appends a single byte to the output destination.
    @inlinable public mutating
    func append(_ byte:UInt8)
    {
        self.destination.append(byte)
    }
    /// Appends a sequence of bytes to the output destination.
    @inlinable public mutating
    func append(_ bytes:some Sequence<UInt8>)
    {
        self.destination.append(contentsOf: bytes)
    }
}
extension BSON.Output
{
    /// Serializes the UTF-8 code units of a string as a c-string with a trailing
    /// null byte. The `cString` must not contain null bytes. Use ``serialize(utf8:)`` 
    /// to serialize a string that contains interior null bytes.
    @inlinable public mutating
    func serialize(cString:String)
    {
        self.append(cString.utf8)
        self.append(0x00)
    }
    /// Serializes a fixed-width integer in little-endian byte order.
    @inlinable public mutating
    func serialize(integer:some FixedWidthInteger)
    {
        withUnsafeBytes(of: integer.littleEndian)
        {
            self.append($0)
        }
    }
    @inlinable public mutating
    func serialize(id:BSON.Identifier)
    {
        withUnsafeBytes(of: id.timestamp.bigEndian)
        {
            self.append($0)
        }
        withUnsafeBytes(of: id.seed)
        {
            self.append($0)
        }
        withUnsafeBytes(of: id.ordinal)
        {
            self.append($0)
        }
    }
    @inlinable public mutating
    func serialize(utf8:BSON.UTF8<some BidirectionalCollection<UInt8>>)
    {
        self.serialize(integer: utf8.header)
        self.append(utf8.bytes)
        self.append(0x00)
    }
    @inlinable public mutating
    func serialize(binary:BSON.Binary<some RandomAccessCollection<UInt8>>)
    {
        self.serialize(integer: binary.header)
        self.append(binary.subtype.rawValue)
        self.append(binary.bytes)
    }
    @inlinable public mutating
    func serialize(document:BSON.Document<some RandomAccessCollection<UInt8>>)
    {
        self.serialize(integer: document.header)
        self.append(document.bytes)
        self.append(0x00)
    }
    @inlinable public mutating
    func serialize(tuple:BSON.Tuple<some RandomAccessCollection<UInt8>>)
    {
        self.serialize(integer: tuple.header)
        self.append(tuple.bytes)
        self.append(0x00)
    }
}
extension BSON.Output
{
    /// Serializes the given variant value, without encoding its type.
    @inlinable public mutating
    func serialize(variant:BSON.Value<some RandomAccessCollection<UInt8>>)
    {
        switch variant
        {
        case .double(let double):
            self.serialize(integer: double.bitPattern)
        
        case .string(let string):
            self.serialize(utf8: string)
        
        case .document(let document):
            self.serialize(document: document)

        case .tuple(let tuple):
            self.serialize(tuple: tuple)

        case .binary(let binary):
            self.serialize(binary: binary)
        
        case .null:
            break
        
        case .id(let id):
            self.serialize(id: id)
        
        case .bool(let bool):
            self.append(bool ? 1 : 0)

        case .millisecond(let millisecond):
            self.serialize(integer: millisecond.value)
        
        case .regex(let regex):
            self.serialize(cString: regex.pattern)
            self.serialize(cString: regex.options.description)
        
        case .pointer(let database, let id):
            self.serialize(utf8: database)
            self.serialize(id: id)
        
        case .javascript(let code):
            self.serialize(utf8: code)
        
        case .javascriptScope(let scope, let code):
            let size:Int32 = 4 + Int32.init(scope.size) + Int32.init(code.size)
            self.serialize(integer: size)
            self.serialize(utf8: code)
            self.serialize(document: scope)
        
        case .int32(let int32):
            self.serialize(integer: int32)
        
        case .uint64(let uint64):
            self.serialize(integer: uint64)
        
        case .int64(let int64):
            self.serialize(integer: int64)

        case .decimal128(let decimal):
            self.serialize(integer: decimal.low)
            self.serialize(integer: decimal.high)
        
        case .max:
            break
        case .min:
            break
        }
    }
    /// Serializes the raw type code of the given variant value, followed by
    /// the field key (with a trailing null byte), followed by the variant value
    /// itself.
    @inlinable public mutating
    func serialize(key:String, value:BSON.Value<some RandomAccessCollection<UInt8>>)
    {
        self.append(value.type.rawValue)
        self.serialize(cString: key)
        self.serialize(variant: value)
    }
    @inlinable public mutating
    func serialize<Bytes>(fields:some Sequence<(key:String, value:BSON.Value<Bytes>)>)
        where Bytes:RandomAccessCollection<UInt8>
    {
        for (key, value):(String, BSON.Value<Bytes>) in fields
        {
            self.serialize(key: key, value: value)
        }
    }
}
extension BSON.Output
{
    /// Serializes the given fields, making two passes over the collection
    /// of fields in order to encode the output without reallocations.
    ///
    /// The destination buffer will not include the trailing null byte
    /// found when a sequence of fields is stored within a BSON document,
    /// but the destination buffer *will* contain space for a null byte to
    /// be appended by the caller without triggering a reallocation, as
    /// long as the `Destination` type supports preallocation.
    @inlinable public
    init(fields:some Collection<(key:String, value:BSON.Value<some RandomAccessCollection<UInt8>>)>)
    {
        let size:Int = fields.reduce(0) { $0 + 2 + $1.key.utf8.count + $1.value.size }
        self.init(capacity: size)
        self.serialize(fields: fields)
        assert(self.destination.count == size,
            "precomputed size (\(size)) does not match output size (\(self.destination.count))")
    }
}
