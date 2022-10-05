import Sediment

typealias OriginalHead<Value> = Sediment<Version.Revision, Value>.Head
/// A descriptor for a field of a symbol that was founded in a different 
/// branch than the branch the descriptor lives in, whose value has diverged 
/// from the value it held when the descriptor’s branch was forked from 
/// its trunk.
struct AlternateHead<Value>
{
    var head:Sediment<Version.Revision, Value>.Head
    /// The first revision in which this field diverged from its parent branch.
    let since:Version.Revision
}
enum PeriodHead<Value>
{
    case original(OriginalHead<Value>?)
    case alternate(AlternateHead<Value>?)
}

extension Optional
{
    subscript<Value>(since revision:Version.Revision) -> OriginalHead<Value>?
        where Wrapped == AlternateHead<Value>
    {
        _read
        {
            yield self?.head
        }
        _modify
        {
            if  let existing:AlternateHead<Value> = self 
            {
                var head:OriginalHead<Value>? = existing.head
                let revision:Version.Revision = existing.since
                yield &head
                self = head.map { .init(head: $0, since: revision) }
            }
            else 
            {
                var head:OriginalHead<Value>? = nil
                yield &head 
                self = head.map { .init(head: $0, since: revision) }
            }
        }
    }
}
