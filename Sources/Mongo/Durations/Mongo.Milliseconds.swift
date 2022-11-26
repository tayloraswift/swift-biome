extension Mongo
{
    public
    typealias Milliseconds = Duration<Millisecond>
}
extension Mongo.Milliseconds
{
    @inlinable public
    init(truncating duration:Duration)
    {
        self.init(rawValue: duration.components.seconds * 1_000 +
            duration.components.attoseconds / 1_000_000_000_000_000)
    }

    @inlinable public static
    func milliseconds(_ milliseconds:Int64) -> Self
    {
        .init(rawValue: milliseconds)
    }
    @inlinable public static
    func seconds(_ seconds:Mongo.Seconds) -> Self
    {
        .init(rawValue: seconds.rawValue * 1_000)
    }
    @inlinable public static
    func minutes(_ minutes:Mongo.Minutes) -> Self
    {
        .init(rawValue: minutes.rawValue * 60_000)
    }
}
