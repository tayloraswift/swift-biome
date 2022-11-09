extension BSON
{
    /// A variant code did not encode a valid BSON type.
    @frozen public
    struct TypeError:Equatable, Error
    {
        public
        let code:UInt8

        @inlinable public
        init(invalid code:UInt8)
        {
            self.code = code
        }
    }
}
extension BSON.TypeError:CustomStringConvertible
{
    public 
    var description:String
    {
        "invalid variant type code (\(self.code))"
    }
}
