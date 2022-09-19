/// A compound symbol. 
/// 
/// This type provides a static guarantee that [`self.host != self.base`]().
struct Compound 
{
    let base:Position<Symbol>
    let diacritic:Diacritic
    
    init?(diacritic:Diacritic, base:Position<Symbol>)
    {
        guard diacritic.host != base 
        else 
        {
            return nil 
        }
        self.diacritic = diacritic 
        self.base = base 
    }

    var host:Position<Symbol>
    {
        self.diacritic.host 
    }
    var culture:Position<Module>
    {
        self.diacritic.culture
    }
    var nationality:Package.Index
    {
        self.diacritic.nationality
    }
}