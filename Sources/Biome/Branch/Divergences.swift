struct Divergences<Key, Divergence> where Key:Hashable
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
}