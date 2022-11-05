extension BSON.Regex
{
    /// A MongoDB regex matching options string contained an invalid unicode scalar.
    @frozen public
    struct OptionError:Equatable, Error
    {
        public
        let codepoint:Unicode.Scalar

        @inlinable public
        init(invalid codepoint:Unicode.Scalar)
        {
            self.codepoint = codepoint
        }
    }
}
extension BSON.Regex.OptionError:CustomStringConvertible
{
    public
    var description:String
    {
        "invalid regex option '\(self.codepoint)'"
    }
}
