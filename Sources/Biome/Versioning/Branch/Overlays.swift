import Sediment

struct Overlays:Sendable
{
    var divergences:[Diacritic: Overlay.Divergence]

    init()
    {
        self.divergences = [:]
    }
}
extension Overlays:PeriodAxis
{
    typealias Key = Diacritic
    typealias Element = Overlay

    subscript<Value>(field:Field<Value>) -> PeriodHead<Value>
    {
        .alternate(self.divergences[field.key][keyPath: field.alternate])
    }
}
extension Overlays:BranchAxis
{
    subscript<Value>(field:Field<Value>) -> OriginalHead<Value>?
    {
        _read
        {
            yield self.divergences[field.key][keyPath: field.alternate]?.head
        }
    }
    subscript<Value>(field:Field<Value>, 
        since revision:Version.Revision) -> OriginalHead<Value>?
    {
        _read
        {
            yield self[field]
        }
        _modify
        {
            yield &self.divergences[field.key][keyPath: field.alternate][since: revision]
        }
    }
}
