extension Mongo
{
    public
    typealias Seconds = Duration<Second>
}
extension Mongo.Seconds
{
    @inlinable public static
    func seconds(_ seconds:Int64) -> Self
    {
        .init(rawValue: seconds)
    }
    @inlinable public static
    func minutes(_ minutes:Mongo.Minutes) -> Self
    {
        .init(rawValue: minutes.rawValue * 60)
    }
}
extension Mongo.Seconds
{
    @inlinable public
    var milliseconds:Mongo.Milliseconds
    {
        .init(rawValue: 1_000 * self.rawValue)
    }
}
