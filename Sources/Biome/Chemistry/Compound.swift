/// A compound symbol. 
/// 
/// This type provides a static guarantee that [`self.host != self.base`]().
struct Compound:Hashable, Sendable
{
    let base:Atom<Symbol>
    let diacritic:Diacritic
    
    init?(diacritic:Diacritic, base:Atom<Symbol>)
    {
        guard diacritic.host != base 
        else 
        {
            return nil 
        }
        self.diacritic = diacritic 
        self.base = base 
    }

    var host:Atom<Symbol>
    {
        self.diacritic.host 
    }
    var culture:Atom<Module>
    {
        self.diacritic.culture
    }
    var nationality:Package.Index
    {
        self.diacritic.nationality
    }
}