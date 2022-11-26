import BSONSchema

extension Mongo
{
    public
    enum Minute
    {
    }
    public
    enum Second
    {
    }
    public
    enum Millisecond
    {
    }

    @frozen public
    struct Duration<Unit>:RawRepresentable, Hashable, Sendable
    {
        public
        let rawValue:Int64

        @inlinable public
        init(rawValue:Int64)
        {
            self.rawValue = rawValue
        }
    }
}

extension Mongo.Duration:Comparable
{
    @inlinable public static
    func < (lhs:Self, rhs:Self) -> Bool
    {
        lhs.rawValue < rhs.rawValue
    }
}
extension Mongo.Duration:AdditiveArithmetic
{
    @inlinable public static
    var zero:Self
    {
        .init(rawValue: 0)
    }

    @inlinable public static
    func + (lhs:Self, rhs:Self) -> Self
    {
        .init(rawValue: lhs.rawValue + rhs.rawValue)
    }
    @inlinable public static
    func - (lhs:Self, rhs:Self) -> Self
    {
        .init(rawValue: lhs.rawValue - rhs.rawValue)
    }
}
extension Mongo.Duration:DurationProtocol
{
    @inlinable public static
    func / (lhs:Self, rhs:Int) -> Self
    {
        .init(rawValue: lhs.rawValue / Int64.init(rhs))
    }

    @inlinable public static
    func * (lhs:Self, rhs:Int) -> Self
    {
        .init(rawValue: lhs.rawValue * Int64.init(rhs))
    }

    @inlinable public static
    func / (lhs:Self, rhs:Self) -> Double
    {
        Double.init(lhs.rawValue) / Double.init(rhs.rawValue)
    }
}
extension Mongo.Duration:ExpressibleByIntegerLiteral
{
    @inlinable public
    init(integerLiteral:Int64)
    {
        self.init(rawValue: integerLiteral)
    }
}
extension Mongo.Duration:BSONScheme
{
}
