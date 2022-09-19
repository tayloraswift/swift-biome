struct Diacritic:Hashable, Sendable
{
    let host:Position<Symbol> 
    let culture:Position<Module>
    
    init(host:Position<Symbol>, culture:Position<Module>)
    {
        self.host = host 
        self.culture = culture
    }
    
    init(natural:Position<Symbol>)
    {
        self.host = natural 
        self.culture = natural.culture
    }

    var nationality:Package.Index 
    {
        self.culture.culture 
    }
}