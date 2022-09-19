// 20 B size, 24 B stride
@usableFromInline
struct Composite:Hashable, Sendable
{
    //  there are up to three cultures that come into play here:
    //  1. host culture 
    //  2. witness culture 
    //  3. perpetrator culture
    let base:Position<Symbol>
    let diacritic:Diacritic 
            
    init(natural:Position<Symbol>) 
    {
        self.base = natural
        self.diacritic = .init(natural: natural)
    }
    init(_ base:Position<Symbol>, _ diacritic:Diacritic) 
    {
        self.base = base 
        self.diacritic = diacritic
    }

    var culture:Position<Module>
    {
        self.diacritic.culture
    }
    var nationality:Package.Index 
    {
        self.diacritic.nationality 
    }

    var isAtomic:Bool 
    {
        self.base == self.diacritic.host
    }
    var compound:Compound? 
    {
        .init(diacritic: self.diacritic, base: self.base)
    }
    var atom:Position<Symbol>? 
    {
        self.isAtomic ? self.base : nil
    }
    var host:Position<Symbol>? 
    {
        self.isAtomic ? nil : self.diacritic.host 
    }
}