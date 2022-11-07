

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