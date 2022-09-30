// 20 B size, 24 B stride
@usableFromInline
struct Composite:Hashable, Sendable
{
    //  there are up to three cultures that come into play here:
    //  1. host culture 
    //  2. witness culture 
    //  3. perpetrator culture
    let base:Atom<Symbol>
    let diacritic:Diacritic 
    
    init(atomic:Atom<Symbol>) 
    {
        self.base = atomic
        self.diacritic = .init(atomic: atomic)
    }
    init(_ base:Atom<Symbol>, _ diacritic:Diacritic) 
    {
        self.base = base 
        self.diacritic = diacritic
    }

    var culture:Atom<Module>
    {
        self.diacritic.culture
    }
    var nationality:Packages.Index 
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
    var atom:Atom<Symbol>? 
    {
        self.isAtomic ? self.base : nil
    }
    var host:Atom<Symbol>? 
    {
        self.isAtomic ? nil : self.diacritic.host 
    }
}