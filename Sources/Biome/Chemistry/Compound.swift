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
    var nationality:Packages.Index
    {
        self.diacritic.nationality
    }
}
extension Compound 
{
    func positioned(bisecting trunk:some RandomAccessCollection<Epoch<Module>>, 
        host:some RandomAccessCollection<Epoch<Symbol>>, 
        base:some RandomAccessCollection<Epoch<Symbol>>) -> Position?
    {
        if  let culture:Version.Branch = self.culture.positioned(bisecting: trunk)?.branch, 
            let host:Version.Branch = self.host.positioned(bisecting: host)?.branch,
            let base:Version.Branch = self.base.positioned(bisecting: base)?.branch
        {
            return .init(self, culture: culture, host: host, base: base)
        }
        else 
        {
            return nil
        }
    }
}