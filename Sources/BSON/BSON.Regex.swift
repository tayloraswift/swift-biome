extension BSON
{
    /// A MongoDB regex.
    @frozen public 
    struct Regex:Equatable, Sendable
    {
        public 
        var pattern:String 
        public 
        var options:Options

        @inlinable public
        init(pattern:String, options:Options)
        {
            self.pattern = pattern
            self.options = options
        }
    }
}
extension BSON.Regex
{
    @inlinable public
    init(pattern:String, options:some StringProtocol) throws
    {
        self.init(pattern: pattern, options: try .init(parsing: options))
    }

    /// The size of this regex when encoded with interior and trailing null bytes.
    @inlinable public
    var size:Int
    {
        1 + self.pattern.utf8.count + self.options.size
    }
}
