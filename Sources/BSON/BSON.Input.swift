import BSONTraversal

extension BSON
{
    /// A parser did not receive the expected amount of input.
    public
    enum EndOfInputError:Equatable, Error
    {
        /// Expected end-of-input, but encountered additional trailing bytes.
        case expected(encountered:Int)
        /// Unexpected end-of-input
        case unexpected
    }
}
extension BSON.EndOfInputError:CustomStringConvertible
{
    public
    var description:String
    {
        switch self
        {
        case .expected(encountered: let bytes):
            return "expected end-of-input, encountered \(bytes) additional trailing byte(s)"
        case .unexpected:
            return "unexpected end-of-input"
        }
    }
}
extension BSON
{
    public
    struct HeaderError<Traversable>:Equatable, Error where Traversable:TraversableBSON
    {
        public
        let length:Int

        public
        init(length:Int)
        {
            self.length = length
        }
    }
}
extension BSON.HeaderError:CustomStringConvertible
{
    public
    var description:String
    {
        "length declared in header (\(self.length)) is less than the minimum for type '\(Traversable.self)' (\(Traversable.headerSize))"
    }
}
extension BSON
{
    /// A type for managing BSON parsing state. Most users of this module
    /// should not need to interact with it directly.
    @frozen public
    struct Input<Source> where Source:RandomAccessCollection<UInt8>
    {
        public
        let source:Source
        public
        var index:Source.Index

        /// Creates a parsing input view over the given `source` data,
        /// and initializes its ``index`` to the start index of the `source`.
        @inlinable public
        init(_ source:Source)
        {
            self.source = source
            self.index = self.source.startIndex
        }
    }
}
extension BSON.Input
{
    /// Consumes and returns a single byte from this parsing input.
    @inlinable public mutating
    func next() -> UInt8?
    {
        guard self.index < self.source.endIndex
        else
        {
            return nil
        }
        defer
        {
            self.source.formIndex(after: &self.index)
        }
        
        return self.source[self.index]
    }
    /// Advances the current index until encountering the specified `byte`.
    /// After this method returns, ``index`` points to the byte after
    /// the matched byte.
    ///
    /// -   Returns:
    ///         A range covering the bytes skipped. The upper-bound of
    ///         the range points to the matched byte.
    @discardableResult
    @inlinable public mutating
    func parse(through byte:UInt8) throws -> Range<Source.Index>
    {
        let start:Source.Index = self.index
        while self.index < self.source.endIndex
        {
            defer
            {
                self.source.formIndex(after: &self.index)
            }
            if  self.source[self.index] == byte
            {
                return start ..< self.index
            }
        }
        throw BSON.EndOfInputError.unexpected
    }
    /// Parses a null-terminated string.
    @inlinable public mutating
    func parse(as _:String.Type = String.self) throws -> String
    {
        .init(decoding: self.source[try self.parse(through: 0x00)], as: Unicode.UTF8.self)
    }
    /// Parses a MongoDB object reference.
    @inlinable public mutating
    func parse(as _:BSON.Identifier.Type = BSON.Identifier.self) throws -> BSON.Identifier
    {
        let start:Source.Index = self.index
        if  let end:Source.Index = self.source.index(self.index, offsetBy: 12, 
                limitedBy: self.source.endIndex)
        {
            self.index = end
            return withUnsafeTemporaryAllocation(byteCount: 12,
                alignment: MemoryLayout<UInt32>.alignment)
            {
                $0.copyBytes(from: self.source[start ..< end])
                //  timestamp is big-endian!
                return .init(timestamp: .init(bigEndian: $0.load(as: UInt32.self)), 
                    $0.loadUnaligned(fromByteOffset: 4,
                        as: BSON.Identifier.Seed.self), 
                    $0.loadUnaligned(fromByteOffset: 9, 
                        as: BSON.Identifier.Ordinal.self))
            }
        }
        else
        {
            throw BSON.EndOfInputError.unexpected
        }
    }
    /// Parses a little-endian integer.
    @inlinable public mutating
    func parse<LittleEndian>(as _:LittleEndian.Type = LittleEndian.self) throws -> LittleEndian
        where LittleEndian:FixedWidthInteger
    {
        let start:Source.Index = self.index
        if  let end:Source.Index = self.source.index(self.index, 
                offsetBy: MemoryLayout<LittleEndian>.size, 
                limitedBy: self.source.endIndex)
        {
            self.index = end
            return withUnsafeTemporaryAllocation(
                byteCount: MemoryLayout<LittleEndian>.size,
                alignment: MemoryLayout<LittleEndian>.alignment)
            {
                $0.copyBytes(from: self.source[start ..< end])
                return .init(littleEndian: $0.load(as: LittleEndian.self))
            }
        }
        else
        {
            throw BSON.EndOfInputError.unexpected
        }
    }
    /// Parses a traversable BSON element. The output is typically opaque,
    /// which allows decoders to skip over regions of a BSON document.
    @inlinable public mutating
    func parse<Traversable>(as _:Traversable.Type = Traversable.self) throws -> Traversable
        where Traversable:TraversableBSON<Source.SubSequence>
    {
        let count:Int = .init(try self.parse(as: Int32.self))
        if  count < Traversable.headerSize
        {
            throw BSON.HeaderError<Traversable>.init(length: count)
        }
        let start:Source.Index = self.index

        if  let end:Source.Index = self.source.index(self.index, 
                offsetBy: count - Traversable.headerSize, 
                limitedBy: self.source.endIndex)
        {
            self.index = end
            return try .init(slicing: self.source[start ..< end])
        }
        else
        {
            throw BSON.EndOfInputError.unexpected
        }
    }
    /// Asserts that there is no input remaining.
    @inlinable public
    func finish() throws
    {
        if self.index != self.source.endIndex
        {
            throw BSON.EndOfInputError.expected(
                encountered: self.source.distance(from: self.index, to: self.source.endIndex))
        }
    }
}
extension BSON.Input
{
    /// Parses a variant BSON value, assuming it is of the specified `variant` type.
    @inlinable public mutating
    func parse(variant:BSON) throws -> BSON.Variant<Source.SubSequence>
    {
        switch variant
        {
        case .double:
            return .double(.init(bitPattern: try self.parse(as: UInt64.self)))
        
        case .string:
            return .string(try self.parse(as: BSON.UTF8<Source.SubSequence>.self).description)
        
        case .document:
            return .document(try self.parse(as: BSON.Document<Source.SubSequence>.self))
        
        case .tuple:
            return .tuple(try self.parse(as: BSON.Tuple<Source.SubSequence>.self))
        
        case .binary:
            return .binary(try self.parse(as: BSON.Binary<Source.SubSequence>.self))
        
        case .null:
            return .null
        
        case .id:
            return .id(try self.parse(as: BSON.Identifier.self))
        
        case .bool:
            switch self.next()
            {
            case 0?:
                return .bool(false)
            case 1?:
                return .bool(true)
            case let code?:
                throw BSON.BooleanSubtypeError.invalid(code)
            case nil:
                throw BSON.EndOfInputError.unexpected
            }
        
        case .millisecond:
            return .millisecond(try self.parse(as: Int64.self))
        
        case .regex:
            let pattern:String = try self.parse(as: String.self)
            let options:String = try self.parse(as: String.self)
            return .regex(try .init(pattern: pattern, options: options))
        
        case .pointer:
            let database:String = try self.parse(as: BSON.UTF8<Source.SubSequence>.self)
                .description
            let object:BSON.Identifier = try self.parse(as: BSON.Identifier.self)
            return .pointer(database, object)
        
        case .javascript:
            return .javascript(try self.parse(as: BSON.UTF8<Source.SubSequence>.self))
        
        case .javascriptScope:
            // possible micro-optimization here
            let _:Int32 = try self.parse(as: Int32.self)
            let code:BSON.UTF8<Source.SubSequence> = 
                try self.parse(as: BSON.UTF8<Source.SubSequence>.self)
            let scope:BSON.Document<Source.SubSequence> = 
                try self.parse(as: BSON.Document<Source.SubSequence>.self)
            return .javascriptScope(scope, code)
        
        case .int32:
            return .int32(try self.parse(as: Int32.self))
        
        case .uint64:
            return .uint64(try self.parse(as: UInt64.self))
        
        case .int64:
            return .int64(try self.parse(as: Int64.self))
        
        case .decimal128:
            let low:UInt64 = try self.parse(as: UInt64.self)
            let high:UInt64 = try self.parse(as: UInt64.self)
            return .decimal128(.init(high: high, low: low))
        
        case .max:
            return .max
        case .min:
            return .min
        }
    }
}
