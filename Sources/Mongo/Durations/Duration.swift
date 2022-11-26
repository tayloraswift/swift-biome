extension Duration
{
    @inlinable public static
    func minutes(_ minutes:Mongo.Minutes) -> Self
    {
        .seconds(minutes.seconds)
    }
    @inlinable public static
    func seconds(_ seconds:Mongo.Seconds) -> Self
    {
        .seconds(seconds.rawValue)
    }
    @inlinable public static
    func milliseconds(_ milliseconds:Mongo.Milliseconds) -> Self
    {
        .milliseconds(milliseconds.rawValue)
    }
}
