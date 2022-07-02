extension Symbol 
{
    @usableFromInline 
    struct Diacritic:Hashable, Sendable
    {
        let host:Index 
        let culture:Module.Index
        
        init(host:Index, culture:Module.Index)
        {
            self.host = host 
            self.culture = culture
        }
        
        init(natural:Index)
        {
            self.host = natural 
            self.culture = natural.module
        }
    }
}
