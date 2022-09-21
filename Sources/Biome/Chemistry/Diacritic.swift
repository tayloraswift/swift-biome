struct Diacritic:Hashable, Sendable
{
    let host:Atom<Symbol> 
    let culture:Atom<Module>
    
    init(host:Atom<Symbol>, culture:Atom<Module>)
    {
        self.host = host 
        self.culture = culture
    }
    @available(*, deprecated, renamed: "init(atomic:)")
    init(natural:Atom<Symbol>)
    {
        self.init(atomic: natural)
    }
    init(atomic:Atom<Symbol>)
    {
        self.host = atomic
        self.culture = atomic.culture
    }

    var nationality:Package.Index 
    {
        self.culture.culture 
    }
}