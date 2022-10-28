import BSONTraversal

extension BSON
{
    @frozen public
    struct Output<Destination> where Destination:RangeReplaceableCollection<UInt8>
    {
        public
        var destination:Destination

        @inlinable public
        init(capacity:Int)
        {
            self.destination = .init()
            self.destination.reserveCapacity(capacity)
        }
    }
}
extension BSON.Output
{
    /// Appends a single byte to the output destination.
    @inlinable public mutating
    func append(_ byte:UInt8)
    {
        self.destination.append(byte)
    }
    /// Appends a single byte to the output destination.
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
    }
    @inlinable public mutating
    func serialize(array:BSON.Array<some RandomAccessCollection<UInt8>>)
    {
        self.serialize(integer: array.header)
        self.append(array.bytes)
    }
}
extension BSON.Output
{
    @inlinable public mutating
    func serialize<Bytes>(variant:BSON.Variant<Bytes>)
    {
        switch variant
        {
        case .double(let double):
            self.serialize(integer: double.bitPattern)
        
        case .string(let string):
            self.serialize(utf8: .init(string))
        
        case .document(let document):
            self.serialize(document: document)

        case .array(let array):
            self.serialize(array: array)

        case .binary(let binary):
            self.serialize(binary: binary)
        
        case .null:
            break
        
        case .id(let id):
            self.serialize(id: id)
        
        case .bool(let bool):
            self.append(bool ? 1 : 0)

        case .millisecond(let millisecond):
            self.serialize(integer: millisecond)
        
        case .regex(let regex):
            self.serialize(cString: regex.pattern)
            self.serialize(cString: regex.options.description)
        
        case .pointer(let database, let id):
            self.serialize(utf8: .init(database))
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
}
