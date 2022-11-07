

extension BSON.Value
{
    @inlinable public 
    func `as`(_:Bool.Type) throws -> Bool
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:Bool?.Type) throws -> Bool?
    {
        try self.flatMatch(Self.as(_:))
    }
}

extension BSON.Value
{
    @inlinable public 
    func `as`(_:BSON.Decimal128.Type) throws -> BSON.Decimal128
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Decimal128?.Type) throws -> BSON.Decimal128?
    {
        try self.flatMatch(Self.as(_:))
    }
}

extension BSON.Value
{
    @inlinable public 
    func `as`(_:String.Type) throws -> String
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:String?.Type) throws -> String?
    {
        try self.flatMatch(Self.as(_:))
    }
}

extension BSON.Value
{
    @inlinable public 
    func `as`(_:BSON.Regex.Type) throws -> BSON.Regex
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Regex?.Type) throws -> BSON.Regex?
    {
        try self.flatMatch(Self.as(_:))
    }
}

extension BSON.Value
{
    @inlinable public 
    func `as`(_:BSON.Identifier.Type) throws -> BSON.Identifier
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Identifier?.Type) throws -> BSON.Identifier?
    {
        try self.flatMatch(Self.as(_:))
    }
}

extension BSON.Value
{
    @inlinable public 
    func `as`(_:BSON.Millisecond.Type) throws -> BSON.Millisecond
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Millisecond?.Type) throws -> BSON.Millisecond?
    {
        try self.flatMatch(Self.as(_:))
    }
}

extension BSON.Value
{
    @inlinable public 
    func `as`(_:BSON.Tuple<Bytes>.Type) throws -> BSON.Tuple<Bytes>
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Tuple<Bytes>?.Type) throws -> BSON.Tuple<Bytes>?
    {
        try self.flatMatch(Self.as(_:))
    }
}

extension BSON.Value
{
    @inlinable public 
    func `as`(_:BSON.Document<Bytes>.Type) throws -> BSON.Document<Bytes>
    {
        try self.match(Self.as(_:))
    }
    @inlinable public 
    func `as`(_:BSON.Document<Bytes>?.Type) throws -> BSON.Document<Bytes>?
    {
        try self.flatMatch(Self.as(_:))
    }
}

extension BSON.Array
{
    @inlinable public
    func decode(_ index:Int,
        as _:Bool.Type = Bool.self) throws -> Bool
    {
        try self.decode(index) { try $0.as(Bool.self) }
    }
    @inlinable public
    func decode(_ index:Int,
        as _:Bool?.Type = Bool?.self) throws -> Bool?
    {
        try self.decode(index) { try $0.as(Bool?.self) }
    }
}

extension BSON.Array
{
    @inlinable public
    func decode(_ index:Int,
        as _:BSON.Decimal128.Type = BSON.Decimal128.self) throws -> BSON.Decimal128
    {
        try self.decode(index) { try $0.as(BSON.Decimal128.self) }
    }
    @inlinable public
    func decode(_ index:Int,
        as _:BSON.Decimal128?.Type = BSON.Decimal128?.self) throws -> BSON.Decimal128?
    {
        try self.decode(index) { try $0.as(BSON.Decimal128?.self) }
    }
}

extension BSON.Array
{
    @inlinable public
    func decode(_ index:Int,
        as _:String.Type = String.self) throws -> String
    {
        try self.decode(index) { try $0.as(String.self) }
    }
    @inlinable public
    func decode(_ index:Int,
        as _:String?.Type = String?.self) throws -> String?
    {
        try self.decode(index) { try $0.as(String?.self) }
    }
}

extension BSON.Array
{
    @inlinable public
    func decode(_ index:Int,
        as _:BSON.Regex.Type = BSON.Regex.self) throws -> BSON.Regex
    {
        try self.decode(index) { try $0.as(BSON.Regex.self) }
    }
    @inlinable public
    func decode(_ index:Int,
        as _:BSON.Regex?.Type = BSON.Regex?.self) throws -> BSON.Regex?
    {
        try self.decode(index) { try $0.as(BSON.Regex?.self) }
    }
}

extension BSON.Array
{
    @inlinable public
    func decode(_ index:Int,
        as _:BSON.Identifier.Type = BSON.Identifier.self) throws -> BSON.Identifier
    {
        try self.decode(index) { try $0.as(BSON.Identifier.self) }
    }
    @inlinable public
    func decode(_ index:Int,
        as _:BSON.Identifier?.Type = BSON.Identifier?.self) throws -> BSON.Identifier?
    {
        try self.decode(index) { try $0.as(BSON.Identifier?.self) }
    }
}

extension BSON.Array
{
    @inlinable public
    func decode(_ index:Int,
        as _:BSON.Millisecond.Type = BSON.Millisecond.self) throws -> BSON.Millisecond
    {
        try self.decode(index) { try $0.as(BSON.Millisecond.self) }
    }
    @inlinable public
    func decode(_ index:Int,
        as _:BSON.Millisecond?.Type = BSON.Millisecond?.self) throws -> BSON.Millisecond?
    {
        try self.decode(index) { try $0.as(BSON.Millisecond?.self) }
    }
}

extension BSON.Array
{
    @inlinable public
    func decode(_ index:Int,
        as _:BSON.Tuple<Bytes>.Type = BSON.Tuple<Bytes>.self) throws -> BSON.Tuple<Bytes>
    {
        try self.decode(index) { try $0.as(BSON.Tuple<Bytes>.self) }
    }
    @inlinable public
    func decode(_ index:Int,
        as _:BSON.Tuple<Bytes>?.Type = BSON.Tuple<Bytes>?.self) throws -> BSON.Tuple<Bytes>?
    {
        try self.decode(index) { try $0.as(BSON.Tuple<Bytes>?.self) }
    }
}

extension BSON.Array
{
    @inlinable public
    func decode(_ index:Int,
        as _:BSON.Document<Bytes>.Type = BSON.Document<Bytes>.self) throws -> BSON.Document<Bytes>
    {
        try self.decode(index) { try $0.as(BSON.Document<Bytes>.self) }
    }
    @inlinable public
    func decode(_ index:Int,
        as _:BSON.Document<Bytes>?.Type = BSON.Document<Bytes>?.self) throws -> BSON.Document<Bytes>?
    {
        try self.decode(index) { try $0.as(BSON.Document<Bytes>?.self) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode(_ key:String,
        as _:Bool.Type = Bool.self) throws -> Bool
    {
        try self.decode(key) { try $0.as(Bool.self) }
    }
    @inlinable public
    func decode(_ key:String,
        as _:Bool?.Type = Bool?.self) throws -> Bool?
    {
        try self.decode(key) { try $0.as(Bool?.self) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode(_ key:String,
        as _:BSON.Decimal128.Type = BSON.Decimal128.self) throws -> BSON.Decimal128
    {
        try self.decode(key) { try $0.as(BSON.Decimal128.self) }
    }
    @inlinable public
    func decode(_ key:String,
        as _:BSON.Decimal128?.Type = BSON.Decimal128?.self) throws -> BSON.Decimal128?
    {
        try self.decode(key) { try $0.as(BSON.Decimal128?.self) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode(_ key:String,
        as _:String.Type = String.self) throws -> String
    {
        try self.decode(key) { try $0.as(String.self) }
    }
    @inlinable public
    func decode(_ key:String,
        as _:String?.Type = String?.self) throws -> String?
    {
        try self.decode(key) { try $0.as(String?.self) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode(_ key:String,
        as _:BSON.Regex.Type = BSON.Regex.self) throws -> BSON.Regex
    {
        try self.decode(key) { try $0.as(BSON.Regex.self) }
    }
    @inlinable public
    func decode(_ key:String,
        as _:BSON.Regex?.Type = BSON.Regex?.self) throws -> BSON.Regex?
    {
        try self.decode(key) { try $0.as(BSON.Regex?.self) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode(_ key:String,
        as _:BSON.Identifier.Type = BSON.Identifier.self) throws -> BSON.Identifier
    {
        try self.decode(key) { try $0.as(BSON.Identifier.self) }
    }
    @inlinable public
    func decode(_ key:String,
        as _:BSON.Identifier?.Type = BSON.Identifier?.self) throws -> BSON.Identifier?
    {
        try self.decode(key) { try $0.as(BSON.Identifier?.self) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode(_ key:String,
        as _:BSON.Millisecond.Type = BSON.Millisecond.self) throws -> BSON.Millisecond
    {
        try self.decode(key) { try $0.as(BSON.Millisecond.self) }
    }
    @inlinable public
    func decode(_ key:String,
        as _:BSON.Millisecond?.Type = BSON.Millisecond?.self) throws -> BSON.Millisecond?
    {
        try self.decode(key) { try $0.as(BSON.Millisecond?.self) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode(_ key:String,
        as _:BSON.Tuple<Bytes>.Type = BSON.Tuple<Bytes>.self) throws -> BSON.Tuple<Bytes>
    {
        try self.decode(key) { try $0.as(BSON.Tuple<Bytes>.self) }
    }
    @inlinable public
    func decode(_ key:String,
        as _:BSON.Tuple<Bytes>?.Type = BSON.Tuple<Bytes>?.self) throws -> BSON.Tuple<Bytes>?
    {
        try self.decode(key) { try $0.as(BSON.Tuple<Bytes>?.self) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode(_ key:String,
        as _:BSON.Document<Bytes>.Type = BSON.Document<Bytes>.self) throws -> BSON.Document<Bytes>
    {
        try self.decode(key) { try $0.as(BSON.Document<Bytes>.self) }
    }
    @inlinable public
    func decode(_ key:String,
        as _:BSON.Document<Bytes>?.Type = BSON.Document<Bytes>?.self) throws -> BSON.Document<Bytes>?
    {
        try self.decode(key) { try $0.as(BSON.Document<Bytes>?.self) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode(mapping key:String,
        as _:Bool.Type = Bool.self) throws -> Bool?
    {
        try self.decode(mapping: key) { try $0.as(Bool.self) }
    }
    @inlinable public
    func decode(mapping key:String,
        as _:Bool?.Type = Bool?.self) throws -> Bool?
    {
        try self.decode(mapping: key) { try $0.as(Bool?.self) } ?? nil
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode(mapping key:String,
        as _:BSON.Decimal128.Type = BSON.Decimal128.self) throws -> BSON.Decimal128?
    {
        try self.decode(mapping: key) { try $0.as(BSON.Decimal128.self) }
    }
    @inlinable public
    func decode(mapping key:String,
        as _:BSON.Decimal128?.Type = BSON.Decimal128?.self) throws -> BSON.Decimal128?
    {
        try self.decode(mapping: key) { try $0.as(BSON.Decimal128?.self) } ?? nil
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode(mapping key:String,
        as _:String.Type = String.self) throws -> String?
    {
        try self.decode(mapping: key) { try $0.as(String.self) }
    }
    @inlinable public
    func decode(mapping key:String,
        as _:String?.Type = String?.self) throws -> String?
    {
        try self.decode(mapping: key) { try $0.as(String?.self) } ?? nil
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode(mapping key:String,
        as _:BSON.Regex.Type = BSON.Regex.self) throws -> BSON.Regex?
    {
        try self.decode(mapping: key) { try $0.as(BSON.Regex.self) }
    }
    @inlinable public
    func decode(mapping key:String,
        as _:BSON.Regex?.Type = BSON.Regex?.self) throws -> BSON.Regex?
    {
        try self.decode(mapping: key) { try $0.as(BSON.Regex?.self) } ?? nil
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode(mapping key:String,
        as _:BSON.Identifier.Type = BSON.Identifier.self) throws -> BSON.Identifier?
    {
        try self.decode(mapping: key) { try $0.as(BSON.Identifier.self) }
    }
    @inlinable public
    func decode(mapping key:String,
        as _:BSON.Identifier?.Type = BSON.Identifier?.self) throws -> BSON.Identifier?
    {
        try self.decode(mapping: key) { try $0.as(BSON.Identifier?.self) } ?? nil
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode(mapping key:String,
        as _:BSON.Millisecond.Type = BSON.Millisecond.self) throws -> BSON.Millisecond?
    {
        try self.decode(mapping: key) { try $0.as(BSON.Millisecond.self) }
    }
    @inlinable public
    func decode(mapping key:String,
        as _:BSON.Millisecond?.Type = BSON.Millisecond?.self) throws -> BSON.Millisecond?
    {
        try self.decode(mapping: key) { try $0.as(BSON.Millisecond?.self) } ?? nil
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode(mapping key:String,
        as _:BSON.Tuple<Bytes>.Type = BSON.Tuple<Bytes>.self) throws -> BSON.Tuple<Bytes>?
    {
        try self.decode(mapping: key) { try $0.as(BSON.Tuple<Bytes>.self) }
    }
    @inlinable public
    func decode(mapping key:String,
        as _:BSON.Tuple<Bytes>?.Type = BSON.Tuple<Bytes>?.self) throws -> BSON.Tuple<Bytes>?
    {
        try self.decode(mapping: key) { try $0.as(BSON.Tuple<Bytes>?.self) } ?? nil
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode(mapping key:String,
        as _:BSON.Document<Bytes>.Type = BSON.Document<Bytes>.self) throws -> BSON.Document<Bytes>?
    {
        try self.decode(mapping: key) { try $0.as(BSON.Document<Bytes>.self) }
    }
    @inlinable public
    func decode(mapping key:String,
        as _:BSON.Document<Bytes>?.Type = BSON.Document<Bytes>?.self) throws -> BSON.Document<Bytes>?
    {
        try self.decode(mapping: key) { try $0.as(BSON.Document<Bytes>?.self) } ?? nil
    }
}