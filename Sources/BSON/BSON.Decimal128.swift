extension BSON
{
    /// An opaque IEEE 754-2008 decimal.
    @frozen public
    struct Decimal128:Hashable, Equatable, Sendable
    {
        /// The low 64 bits of this decimal value.
        public 
        var low:UInt64
        /// The high 64 bits of this decimal value.
        public 
        var high:UInt64

        @inlinable public
        init(high:UInt64, low:UInt64)
        {
            self.high = high
            self.low = low
        }
    }
}
