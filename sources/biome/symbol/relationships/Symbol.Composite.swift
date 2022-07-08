extension Symbol 
{
    // 20 B size, 24 B stride
    @usableFromInline 
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
        var isNatural:Bool 
        {
            self.base == self.diacritic.host
        }
        var host:Index? 
        {
            self.isNatural ? nil : self.diacritic.host 
        }
        var natural:Index? 
        {
            self.isNatural ? self.base : nil
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
