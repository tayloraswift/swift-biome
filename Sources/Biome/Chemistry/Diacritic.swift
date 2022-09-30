struct Diacritic:Hashable, Sendable
{
    let host:Atom<Symbol> 
    let culture:Atom<Module>
    
    init(host:Atom<Symbol>, culture:Atom<Module>)
    {
        self.host = host 
        self.culture = culture
    }
    
    init(atomic:Atom<Symbol>)
    {
        self.host = atomic
        self.culture = atomic.culture
    }

    var nationality:Packages.Index 
    {
        self.culture.culture 
    }
}