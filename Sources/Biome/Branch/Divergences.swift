struct Divergences<Key, Divergence>:TrunkPeriod where Key:Hashable
{
    private 
    let items:[Key: Divergence]
    let latest:Version 
    let fork:Version?

    init(_ items:[Key: Divergence], latest:Version, fork:Version?)
    {
        self.items = items 
        self.latest = latest 
        self.fork = fork 
    }

    subscript(key:Key) -> Divergence? 
    {
        _read 
        {
            yield self.items[key]
        }
    }
    /// Returns the forest head to the divergent history of the given field, 
    /// if it both exists and began before the specified revision.
    /// 
    /// This head may have been advanced beyond the bounds of the 
    /// ``Buffer/SubSequence`` it was obtained from, if applicable. However 
    /// if this method returns a non-nil result, the specified revision 
    /// is guaranteed to exist in the associated chain.
    subscript<Field, Element>(field:History<Field>.DenseField<Element>) -> History<Field>.Head?
        where Element:BranchElement, Divergence == Element.Divergence, Key == Atom<Element>
    {
        self[field.element, field.divergent]
    }
    subscript<Field>(field:History<Field>.SparseField<Key, Divergence>) -> History<Field>.Head?
    {
        self[field.key, field.divergent]
    }
    private 
    subscript<Field>(key:Key, field:KeyPath<Divergence, History<Field>.Divergent?>) 
        -> History<Field>.Head?
    {
        if  let divergence:History<Field>.Divergent = self.items[key]?[keyPath: field], 
                divergence.start <= self.limit
        {
            return divergence.head
        }
        else 
        {
            return nil
        }
    }
}