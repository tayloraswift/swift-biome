struct Belief 
{
    enum Predicate 
    {
        case `is`(Symbol.Role<PluralPosition<Symbol>>)
        case has(Symbol.Trait<PluralPosition<Symbol>>)
    }

    let subject:PluralPosition<Symbol>
    let predicate:Predicate

    init(_ subject:PluralPosition<Symbol>, _ predicate:Predicate)
    {
        self.subject = subject 
        self.predicate = predicate
    }
}

struct Surface 
{
    var articles:Set<Branch.Position<Article>>
    var symbols:Set<Branch.Position<Symbol>>
    var modules:Set<Branch.Position<Module>>
    var foreign:Set<Branch.Diacritic>

    init(articles:Set<Branch.Position<Article>> = [],
        symbols:Set<Branch.Position<Symbol>> = [],
        modules:Set<Branch.Position<Module>> = [],
        foreign:Set<Branch.Diacritic> = [])
    {
        self.articles = articles
        self.symbols = symbols
        self.modules = modules
        self.foreign = foreign
    }
}
