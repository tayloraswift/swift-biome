extension MongoWire
{
    /// The subtype byte of a binary array was matched a reserved bit pattern.
    @frozen public
    struct FlagsError:Equatable, Error
    {
        public
        let reserved:UInt16
        
        @inlinable public
        init?(flags:UInt32)
        {
            self.reserved = .init(flags & 0b1111_1111_1111_1100)
            if self.reserved == 0
            {
                return nil
            }
        }
    }
}
extension MongoWire.FlagsError:CustomStringConvertible
{
    public
    var description:String
    {
        """
        invalid MongoDB message flags \
        (bit \(self.reserved.trailingZeroBitCount) is set, but is reserved)
        """
    }
}
