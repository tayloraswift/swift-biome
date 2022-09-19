struct Diacritic:Hashable, Sendable
{
    let host:Atom<Symbol> 
    let culture:Atom<Module>
    
    init(host:Atom<Symbol>, culture:Atom<Module>)
    {
        self.host = host 
        self.culture = culture
    }
    
    init(natural:Atom<Symbol>)
    {
        self.host = natural 
        self.culture = natural.culture
    }

    var nationality:Package.Index 
    {
        self.culture.culture 
    }
}