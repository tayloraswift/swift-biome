protocol Periods<Axis>:Collection where Element == Period<Axis>
{
    associatedtype Axis:PeriodAxis

    subscript(index:Int) -> Period<Axis>
    {
        get
    }
}
extension Periods
{
    func find<Element>(_ id:Element.ID) -> Atom<Element>.Position? 
        where Axis == IntrinsicSlice<Element>
    {
        for period:Period<Axis> in self 
        {
            if let atom:Atom<Element> = period.axis.atoms[id]
            {
                return atom.positioned(period.branch)
            }
        }
        return nil
    }
}
