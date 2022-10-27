extension BSON
{
    /// A MongoDB regex.
    @frozen public 
    struct Regex:Sendable
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
}
