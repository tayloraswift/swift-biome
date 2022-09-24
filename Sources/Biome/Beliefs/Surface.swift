struct Belief 
{
    enum Predicate 
    {
        case `is`(Symbol.Role<Atom<Symbol>.Position>)
        case has(Symbol.Trait<Atom<Symbol>.Position>)
    }

    let subject:Atom<Symbol>.Position
    let predicate:Predicate

    init(_ subject:Atom<Symbol>.Position, _ predicate:Predicate)
    {
        self.subject = subject 
        self.predicate = predicate
    }
}

struct Surface 
{
    var articles:Set<Atom<Article>>
    var symbols:Set<Atom<Symbol>>
    var modules:Set<Atom<Module>>
    var foreign:Set<Diacritic>

    init(articles:Set<Atom<Article>> = [],
        symbols:Set<Atom<Symbol>> = [],
        modules:Set<Atom<Module>> = [],
        foreign:Set<Diacritic> = [])
    {
        self.articles = articles
        self.symbols = symbols
        self.modules = modules
        self.foreign = foreign
    }
}
