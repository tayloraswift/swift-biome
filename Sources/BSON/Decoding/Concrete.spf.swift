

extension BSON.Array
{
    @inlinable public
    func decode<T>(_ index:Int,
        as _:Bool.Type,
        with decode:(Bool) throws -> T) throws -> T
    {
        try self.decode(index) { try decode(try $0.as(Bool.self)) }
    }
    @inlinable public
    func decode<T>(_ index:Int,
        as _:Bool?.Type,
        with decode:(Bool) throws -> T) throws -> T?
    {
        try self.decode(index) { try $0.as(Bool?.self).map(decode) }
    }
}

extension BSON.Array
{
    @inlinable public
    func decode<T>(_ index:Int,
        as _:String.Type,
        with decode:(String) throws -> T) throws -> T
    {
        try self.decode(index) { try decode(try $0.as(String.self)) }
    }
    @inlinable public
    func decode<T>(_ index:Int,
        as _:String?.Type,
        with decode:(String) throws -> T) throws -> T?
    {
        try self.decode(index) { try $0.as(String?.self).map(decode) }
    }
}

extension BSON.Array
{
    @inlinable public
    func decode<T>(_ index:Int,
        as _:BSON.Tuple<Bytes>.Type,
        with decode:(BSON.Tuple<Bytes>) throws -> T) throws -> T
    {
        try self.decode(index) { try decode(try $0.as(BSON.Tuple<Bytes>.self)) }
    }
    @inlinable public
    func decode<T>(_ index:Int,
        as _:BSON.Tuple<Bytes>?.Type,
        with decode:(BSON.Tuple<Bytes>) throws -> T) throws -> T?
    {
        try self.decode(index) { try $0.as(BSON.Tuple<Bytes>?.self).map(decode) }
    }
}

extension BSON.Array
{
    @inlinable public
    func decode<T>(_ index:Int,
        as _:BSON.Array<Bytes.SubSequence>.Type,
        with decode:(BSON.Array<Bytes.SubSequence>) throws -> T) throws -> T
    {
        try self.decode(index) { try decode(try $0.as(BSON.Array<Bytes.SubSequence>.self)) }
    }
    @inlinable public
    func decode<T>(_ index:Int,
        as _:BSON.Array<Bytes.SubSequence>?.Type,
        with decode:(BSON.Array<Bytes.SubSequence>) throws -> T) throws -> T?
    {
        try self.decode(index) { try $0.as(BSON.Array<Bytes.SubSequence>?.self).map(decode) }
    }
}

extension BSON.Array
{
    @inlinable public
    func decode<T>(_ index:Int,
        as _:BSON.Document<Bytes>.Type,
        with decode:(BSON.Document<Bytes>) throws -> T) throws -> T
    {
        try self.decode(index) { try decode(try $0.as(BSON.Document<Bytes>.self)) }
    }
    @inlinable public
    func decode<T>(_ index:Int,
        as _:BSON.Document<Bytes>?.Type,
        with decode:(BSON.Document<Bytes>) throws -> T) throws -> T?
    {
        try self.decode(index) { try $0.as(BSON.Document<Bytes>?.self).map(decode) }
    }
}

extension BSON.Array
{
    @inlinable public
    func decode<T>(_ index:Int,
        as _:BSON.Dictionary<Bytes.SubSequence>.Type,
        with decode:(BSON.Dictionary<Bytes.SubSequence>) throws -> T) throws -> T
    {
        try self.decode(index) { try decode(try $0.as(BSON.Dictionary<Bytes.SubSequence>.self)) }
    }
    @inlinable public
    func decode<T>(_ index:Int,
        as _:BSON.Dictionary<Bytes.SubSequence>?.Type,
        with decode:(BSON.Dictionary<Bytes.SubSequence>) throws -> T) throws -> T?
    {
        try self.decode(index) { try $0.as(BSON.Dictionary<Bytes.SubSequence>?.self).map(decode) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<T>(_ key:String,
        as _:Bool.Type,
        with decode:(Bool) throws -> T) throws -> T
    {
        try self.decode(key) { try decode(try $0.as(Bool.self)) }
    }
    @inlinable public
    func decode<T>(_ key:String,
        as _:Bool?.Type,
        with decode:(Bool) throws -> T) throws -> T?
    {
        try self.decode(key) { try $0.as(Bool?.self).map(decode) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<T>(_ key:String,
        as _:String.Type,
        with decode:(String) throws -> T) throws -> T
    {
        try self.decode(key) { try decode(try $0.as(String.self)) }
    }
    @inlinable public
    func decode<T>(_ key:String,
        as _:String?.Type,
        with decode:(String) throws -> T) throws -> T?
    {
        try self.decode(key) { try $0.as(String?.self).map(decode) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<T>(_ key:String,
        as _:BSON.Tuple<Bytes>.Type,
        with decode:(BSON.Tuple<Bytes>) throws -> T) throws -> T
    {
        try self.decode(key) { try decode(try $0.as(BSON.Tuple<Bytes>.self)) }
    }
    @inlinable public
    func decode<T>(_ key:String,
        as _:BSON.Tuple<Bytes>?.Type,
        with decode:(BSON.Tuple<Bytes>) throws -> T) throws -> T?
    {
        try self.decode(key) { try $0.as(BSON.Tuple<Bytes>?.self).map(decode) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<T>(_ key:String,
        as _:BSON.Array<Bytes.SubSequence>.Type,
        with decode:(BSON.Array<Bytes.SubSequence>) throws -> T) throws -> T
    {
        try self.decode(key) { try decode(try $0.as(BSON.Array<Bytes.SubSequence>.self)) }
    }
    @inlinable public
    func decode<T>(_ key:String,
        as _:BSON.Array<Bytes.SubSequence>?.Type,
        with decode:(BSON.Array<Bytes.SubSequence>) throws -> T) throws -> T?
    {
        try self.decode(key) { try $0.as(BSON.Array<Bytes.SubSequence>?.self).map(decode) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<T>(_ key:String,
        as _:BSON.Document<Bytes>.Type,
        with decode:(BSON.Document<Bytes>) throws -> T) throws -> T
    {
        try self.decode(key) { try decode(try $0.as(BSON.Document<Bytes>.self)) }
    }
    @inlinable public
    func decode<T>(_ key:String,
        as _:BSON.Document<Bytes>?.Type,
        with decode:(BSON.Document<Bytes>) throws -> T) throws -> T?
    {
        try self.decode(key) { try $0.as(BSON.Document<Bytes>?.self).map(decode) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<T>(_ key:String,
        as _:BSON.Dictionary<Bytes.SubSequence>.Type,
        with decode:(BSON.Dictionary<Bytes.SubSequence>) throws -> T) throws -> T
    {
        try self.decode(key) { try decode(try $0.as(BSON.Dictionary<Bytes.SubSequence>.self)) }
    }
    @inlinable public
    func decode<T>(_ key:String,
        as _:BSON.Dictionary<Bytes.SubSequence>?.Type,
        with decode:(BSON.Dictionary<Bytes.SubSequence>) throws -> T) throws -> T?
    {
        try self.decode(key) { try $0.as(BSON.Dictionary<Bytes.SubSequence>?.self).map(decode) }
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<T>(mapping key:String,
        as _:Bool.Type,
        with decode:(Bool) throws -> T) throws -> T?
    {
        try self.decode(mapping: key) { try decode(try $0.as(Bool.self)) }
    }
    @inlinable public
    func decode<T>(mapping key:String,
        as _:Bool?.Type,
        with decode:(Bool) throws -> T) throws -> T?
    {
        try self.decode(mapping: key) { try $0.as(Bool?.self).map(decode) } ?? nil
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<T>(mapping key:String,
        as _:String.Type,
        with decode:(String) throws -> T) throws -> T?
    {
        try self.decode(mapping: key) { try decode(try $0.as(String.self)) }
    }
    @inlinable public
    func decode<T>(mapping key:String,
        as _:String?.Type,
        with decode:(String) throws -> T) throws -> T?
    {
        try self.decode(mapping: key) { try $0.as(String?.self).map(decode) } ?? nil
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<T>(mapping key:String,
        as _:BSON.Tuple<Bytes>.Type,
        with decode:(BSON.Tuple<Bytes>) throws -> T) throws -> T?
    {
        try self.decode(mapping: key) { try decode(try $0.as(BSON.Tuple<Bytes>.self)) }
    }
    @inlinable public
    func decode<T>(mapping key:String,
        as _:BSON.Tuple<Bytes>?.Type,
        with decode:(BSON.Tuple<Bytes>) throws -> T) throws -> T?
    {
        try self.decode(mapping: key) { try $0.as(BSON.Tuple<Bytes>?.self).map(decode) } ?? nil
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<T>(mapping key:String,
        as _:BSON.Array<Bytes.SubSequence>.Type,
        with decode:(BSON.Array<Bytes.SubSequence>) throws -> T) throws -> T?
    {
        try self.decode(mapping: key) { try decode(try $0.as(BSON.Array<Bytes.SubSequence>.self)) }
    }
    @inlinable public
    func decode<T>(mapping key:String,
        as _:BSON.Array<Bytes.SubSequence>?.Type,
        with decode:(BSON.Array<Bytes.SubSequence>) throws -> T) throws -> T?
    {
        try self.decode(mapping: key) { try $0.as(BSON.Array<Bytes.SubSequence>?.self).map(decode) } ?? nil
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<T>(mapping key:String,
        as _:BSON.Document<Bytes>.Type,
        with decode:(BSON.Document<Bytes>) throws -> T) throws -> T?
    {
        try self.decode(mapping: key) { try decode(try $0.as(BSON.Document<Bytes>.self)) }
    }
    @inlinable public
    func decode<T>(mapping key:String,
        as _:BSON.Document<Bytes>?.Type,
        with decode:(BSON.Document<Bytes>) throws -> T) throws -> T?
    {
        try self.decode(mapping: key) { try $0.as(BSON.Document<Bytes>?.self).map(decode) } ?? nil
    }
}

extension BSON.Dictionary
{
    @inlinable public
    func decode<T>(mapping key:String,
        as _:BSON.Dictionary<Bytes.SubSequence>.Type,
        with decode:(BSON.Dictionary<Bytes.SubSequence>) throws -> T) throws -> T?
    {
        try self.decode(mapping: key) { try decode(try $0.as(BSON.Dictionary<Bytes.SubSequence>.self)) }
    }
    @inlinable public
    func decode<T>(mapping key:String,
        as _:BSON.Dictionary<Bytes.SubSequence>?.Type,
        with decode:(BSON.Dictionary<Bytes.SubSequence>) throws -> T) throws -> T?
    {
        try self.decode(mapping: key) { try $0.as(BSON.Dictionary<Bytes.SubSequence>?.self).map(decode) } ?? nil
    }
}
