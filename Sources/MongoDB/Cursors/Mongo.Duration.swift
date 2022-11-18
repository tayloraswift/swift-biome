extension Mongo
{
    @frozen public
    struct Duration:Hashable, Sendable
    {
        public
        let milliseconds:Int64

        @inlinable public
        init(milliseconds:Int64)
        {
            self.milliseconds = milliseconds
        }
    }
}
extension Mongo.Duration
{
    @inlinable public
    init(_ duration:Duration)
    {
        self.init(milliseconds: duration.components.seconds * 1_000 +
            duration.components.attoseconds / 1_000_000_000_000_000)
    }
}
extension Mongo.Duration:Comparable
{
    @inlinable public static
    func < (lhs:Self, rhs:Self) -> Bool
    {
        lhs.milliseconds < rhs.milliseconds
    }
}
extension Mongo.Duration:AdditiveArithmetic
{
    @inlinable public static
    var zero:Self
    {
        .init(milliseconds: 0)
    }

    @inlinable public static
    func + (lhs:Self, rhs:Self) -> Self
    {
        .init(milliseconds: lhs.milliseconds + rhs.milliseconds)
    }
    @inlinable public static
    func - (lhs:Self, rhs:Self) -> Self
    {
        .init(milliseconds: lhs.milliseconds - rhs.milliseconds)
    }
}
extension Mongo.Duration:DurationProtocol
{
    @inlinable public static
    func / (lhs:Self, rhs:Int) -> Self
    {
        .init(milliseconds: lhs.milliseconds / Int64.init(rhs))
    }

    @inlinable public static
    func * (lhs:Self, rhs:Int) -> Self
    {
        .init(milliseconds: lhs.milliseconds * Int64.init(rhs))
    }

    @inlinable public static
    func / (lhs:Self, rhs:Self) -> Double
    {
        Double.init(lhs.milliseconds) / Double.init(rhs.milliseconds)
    }
}
