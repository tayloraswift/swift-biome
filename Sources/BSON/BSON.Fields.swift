extension BSON
{
    @frozen public
    struct Fields:Sendable
    {
        public
        var output:BSON.Output<[UInt8]>

        @inlinable public
        init(output:BSON.Output<[UInt8]> = .init(capacity: 0))
        {
            self.output = output
        }
    }
}
extension BSON.Fields
{
    /// Creates an empty encoding view and initializes it with the given closure.
    @inlinable public
    init(with populate:(inout BSON.Fields) throws -> ()) rethrows
    {
        self.init()
        try populate(&self)
    }
    /// Creates an encoding view around the given [`[UInt8]`]()-backed
    /// document.
    ///
    /// >   Complexity: O(1).
    @inlinable public
    init(bson:BSON.Document<[UInt8]>)
    {
        self.init(output: .init(preallocated: bson.bytes))
    }
    @inlinable public
    var isEmpty:Bool
    {
        self.output.destination.isEmpty
    }
}
extension BSON.Fields
{
    /// Creates a document containing the given fields.
    /// The order of the fields will be preserved.
    @inlinable public
    init(_ fields:some Collection<(key:String, value:BSON.Value<some RandomAccessCollection<UInt8>>)>)
    {
        self.init(output: .init(fields: fields))
    }
}
extension BSON.Fields:ExpressibleByDictionaryLiteral
{
    @inlinable public
    init(dictionaryLiteral:(String, BSON.Value<[UInt8]>)...)
    {
        self.init(dictionaryLiteral)
    }
}
