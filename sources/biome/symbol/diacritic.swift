extension Symbol 
{
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
    // 20 B size, 24 B stride
    struct Composite:Hashable, Sendable
    {
        //  there are up to three cultures that come into play here:
        //  1. host culture 
        //  2. witness culture 
        //  3. perpetrator culture
        let base:Index
        let diacritic:Diacritic 
        
        var culture:Module.Index
        {
            self.diacritic.culture
        }
        var host:Index? 
        {
            self.base != self.diacritic.host ? self.diacritic.host : nil
        }
        
        init(natural:Index) 
        {
            self.base = natural
            self.diacritic = .init(natural: natural)
        }
        init(_ base:Index, _ diacritic:Diacritic) 
        {
            self.base = base 
            self.diacritic = diacritic
        }
    }
}
