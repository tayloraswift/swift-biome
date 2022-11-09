extension BSON
{
    /// An opaque IEEE 754-2008 decimal.
    ///
    /// This library does not have access to decimal-aware facilities.
    /// Therefore, `Decimal128` instances are not ``Comparable``, at least when
    /// importing this module alone.
    ///
    /// Take caution when using this type’s ``Hashable`` and ``Equatable`` conformances.
    /// Two `Decimal128` values can encode the same numeric value, yet compare unequal
    /// under ``Equatable/.==(_:_:)``.
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
