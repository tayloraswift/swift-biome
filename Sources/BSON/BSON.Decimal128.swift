extension BSON
{
    /// An opaque IEEE 754-2008 decimal.
    @frozen public
    struct Decimal128
    {
        /// The low 64 bits of this decimal value.
        public 
        var low:UInt64
        /// The high 64 bits of this decimal value.
        public 
        var high:UInt64 
    }
}
