// 20 B size, 24 B stride
struct Crime:Hashable, Sendable
{
    //  there are up to three cultures that come into play here:
    //  1. victim culture 
    //  2. witness culture 
    //  3. perpetrator culture
    private 
    let host:Symbol.Index 
    let base:Symbol.Index
    let culture:Module.Index
    
    var victim:Symbol.Index? 
    {
        self.host == self.base ? nil : self.host
    }
    
    init(natural symbol:Symbol.Index) 
    {
        self.host = symbol
        self.base = symbol
        self.culture = symbol.module
    }
    init(victim:Symbol.Index, feature:Symbol.Index, culture:Module.Index) 
    {
        self.host = victim 
        self.base = feature 
        self.culture = culture
    }
}
