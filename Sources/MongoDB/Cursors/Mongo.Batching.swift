extension Mongo
{
    @frozen public
    enum Batching:Hashable, Sendable
    {
        case batches(of:Int)
        case batch(of:Int)
    }
}
