extension Mongo
{
    @frozen public
    enum Tailing:Hashable, Sendable
    {
        case poll
        case await
    }
}
