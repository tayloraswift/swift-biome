extension BSON
{
    /// The subtype byte of a binary array was matched a reserved bit pattern.
    @frozen public
    struct BinarySubtypeError:Equatable, Error
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
extension BSON.BinarySubtypeError:CustomStringConvertible
{
    public 
    var description:String
    {
        "invalid binary subtype code (\(self.code))"
    }
}
