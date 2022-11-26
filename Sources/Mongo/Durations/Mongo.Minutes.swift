extension Mongo
{
    public
    typealias Minutes = Duration<Minute>
}
extension Mongo.Minutes
{
    @inlinable public static
    func minutes(_ minutes:Int64) -> Self
    {
        .init(rawValue: minutes)
    }
}
extension Mongo.Minutes
{
    @inlinable public
    var seconds:Mongo.Seconds
    {
        .init(rawValue: 60 * self.rawValue)
    }
    @inlinable public
    var milliseconds:Mongo.Milliseconds
    {
        .init(rawValue: 60_000 * self.rawValue)
    }
}
