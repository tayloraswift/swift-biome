import BSONEncoding

extension Mongo.Session
{
    public 
    struct ID:Hashable, Sendable 
    {
        let low:UInt64
        let high:UInt64

        static
        var _random:Self
        {
            .init()
        }

        init() 
        {
            self.low = .random(in: .min ... .max)
            self.high = .random(in: .min ... .max)
        }
        
        var bson:BSON.Document<[UInt8]>
        {
            
            return .init()
        }
    }
}
extension Mongo.Session.ID:RandomAccessCollection
{
    @inlinable public 
    var startIndex:Int
    {
        0
    }
    @inlinable public 
    var endIndex:Int
    {
        16
    }
    @inlinable public
    subscript(index:Int) -> UInt8
    {
        withUnsafeBytes(of: self) { $0[index] }
    }
}

extension BSON.Fields where Bytes:RangeReplaceableCollection
{
    /// Adds a MongoDB session identifier to this list of fields, under the key [`"lsid"`]().
    mutating
    func add(session:Mongo.Session.ID)
    {
        let binary:BSON.Binary<Mongo.Session.ID> = .init(subtype: .uuid, bytes: session[...])
        self.add(key: "lsid", value: .document(.init(key: "id", value: .binary(binary))))
    }
}
