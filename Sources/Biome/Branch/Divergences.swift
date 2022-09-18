struct Divergences<Key, Value> where Key:Hashable
{
    private 
    let items:[Key: Value]
    let limit:_Version.Revision

    init(_ items:[Key: Value], limit:_Version.Revision)
    {
        self.items = items 
        self.limit = limit
    }

    subscript(key:Key) -> Value? 
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
    subscript<Field>(key:Key, field:KeyPath<Value, History<Field>.Divergent?>) 
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