import BSONTraversal

extension BSON
{
    /// A parser did not receive the expected amount of input.
    public
    enum ParsingError:Error
    {
        case trailed(bytes:Int)
        case incomplete
    }

    struct ParsingInput<Source> where Source:RandomAccessCollection<UInt8>
    {
        let source:Source
        private(set)
        var index:Source.Index

        init(_ source:Source)
        {
            self.source = source
            self.index = self.source.startIndex
        }
    }
}
extension BSON.ParsingInput
{
    mutating
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
    mutating
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
        throw BSON.ParsingError.incomplete
    }
    /// Parses a null-terminated string.
    mutating
    func parse(as _:String.Type = String.self) throws -> String
    {
        .init(decoding: self.source[try self.parse(through: 0x00)], as: Unicode.UTF8.self)
    }
    /// Parses a MongoDB object reference.
    mutating
    func parse(as _:BSON.Object.Type = BSON.Object.self) throws -> BSON.Object
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
                        as: BSON.Object.Seed.self), 
                    $0.loadUnaligned(fromByteOffset: 9, 
                        as: BSON.Object.Ordinal.self))
            }
        }
        else
        {
            throw BSON.ParsingError.incomplete
        }
    }
    /// Parses a little-endian integer.
    mutating
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
            throw BSON.ParsingError.incomplete
        }
    }
    /// Parses a traversable BSON element. The output is typically opaque,
    /// which allows decoders to skip over regions of a BSON document.
    mutating
    func parse<Traversable>(as _:Traversable.Type = Traversable.self) throws -> Traversable
        where Traversable:TraversableBSON<Source.SubSequence>
    {
        let count:Int = .init(try self.parse(as: Int32.self))
        let start:Source.Index = self.index

        if  let end:Source.Index = self.source.index(self.index, 
                offsetBy: count - Traversable.headerBytes, 
                limitedBy: self.source.endIndex)
        {
            self.index = end
            return try .init(self.source[start ..< end])
        }
        else
        {
            throw BSON.ParsingError.incomplete
        }
    }
}
extension BSON.ParsingInput
{
    /// Parses a variant BSON value, assuming it is of the variant type
    /// encoded by the given tag byte.
    mutating
    func parse(variant:UInt8) throws -> BSON.Variant<Source.SubSequence>
    {
        switch variant
        {
        case 0x01:
            return .double(.init(bitPattern: try self.parse(as: UInt64.self)))
        
        case 0x02:
            return .string(try self.parse(as: BSON.UTF8<Source.SubSequence>.self)
                .description)
        
        case 0x03:
            return .document(try self.parse(as: BSON.Document<Source.SubSequence>.self))
        
        case 0x04:
            return .array(try self.parse(as: BSON.Document<Source.SubSequence>.self))
        
        case 0x05:
            return .binary(try self.parse(as: BSON.Binary<Source.SubSequence>.self))
        
        case 0x06:
            return .null
        
        case 0x07:
            return .object(try self.parse(as: BSON.Object.self))
        
        case 0x08:
            switch self.next()
            {
            case 0?:
                return .bool(false)
            case 1?:
                return .bool(true)
            case let code?:
                throw BSON.BooleanError.invalid(code)
            case nil:
                throw BSON.ParsingError.incomplete
            }
        
        case 0x09:
            return .datetime(try self.parse(as: Int64.self))
        
        case 0x0A:
            return .null
        
        case 0x0B:
            let pattern:String = try self.parse(as: String.self)
            let options:String = try self.parse(as: String.self)
            return .regex(try .init(pattern: pattern, options: options))
        
        case 0x0C:
            let database:String = try self.parse(as: BSON.UTF8<Source.SubSequence>.self)
                .description
            let object:BSON.Object = try self.parse(as: BSON.Object.self)
            return .pointer(database, object)
        
        case 0x0D:
            return .javascript(try self.parse(as: BSON.UTF8<Source.SubSequence>.self))
        
        case 0x0E:
            return .symbol(try self.parse(as: BSON.UTF8<Source.SubSequence>.self))
        
        case 0x0F:
            let code:BSON.UTF8<Source.SubSequence> = 
                try self.parse(as: BSON.UTF8<Source.SubSequence>.self)
            let scope:BSON.Document<Source.SubSequence> = 
                try self.parse(as: BSON.Document<Source.SubSequence>.self)
            return .javascript(code, scope: scope)
        
        case 0x10:
            return .int32(try self.parse(as: Int32.self))
        
        case 0x11:
            return .uint64(try self.parse(as: UInt64.self))
        
        case 0x12:
            return .int64(try self.parse(as: Int64.self))
        
        case 0x13:
            let low:UInt64 = try self.parse(as: UInt64.self)
            let high:UInt64 = try self.parse(as: UInt64.self)
            return .decimal128(.init(low: low, high: high))
        
        case 0x7F:
            return .max
        case 0xFF:
            return .min
        
        case let code:
            throw BSON.TypeError.init(code: code)
        }
    }
}