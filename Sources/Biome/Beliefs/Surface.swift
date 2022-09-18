struct Belief 
{
    enum Predicate 
    {
        case `is`(Symbol.Role<Tree.Position<Symbol>>)
        case has(Symbol.Trait<Tree.Position<Symbol>>)
    }

    let subject:Tree.Position<Symbol>
    let predicate:Predicate

    init(_ subject:Tree.Position<Symbol>, _ predicate:Predicate)
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
