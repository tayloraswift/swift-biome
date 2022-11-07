extension BSON
{
    /// A number of UTC milliseconds since the Unix epoch.
    ///
    /// This library does not have access to calender-aware facilities.
    /// Therefore, UTC milliseconds are not ``Comparable``, at least when importing
    /// this module alone.
    ///
    /// Take caution when using this type’s ``Hashable`` and ``Equatable`` conformances.
    /// Two equivalent `Millisecond` values do not necessarily reference the same
    /// instant in time.
    @frozen public
    struct Millisecond:Hashable, Equatable, Sendable
    {
        public
        let value:Int64

        @inlinable public
        init(_ value:Int64)
        {
            self.value = value
        }
    }
}
extension BSON.Millisecond:ExpressibleByIntegerLiteral
{
    @inlinable public
    init(integerLiteral:Int64)
    {
        self.init(integerLiteral)
    }
}
