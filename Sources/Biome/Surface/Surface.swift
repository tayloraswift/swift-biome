struct Surface 
{
    var articles:Set<Atom<Article>>
    var symbols:Set<Atom<Symbol>>
    var modules:Set<Atom<Module>>
    var overlays:Set<Diacritic>

    init(articles:Set<Atom<Article>> = [],
        symbols:Set<Atom<Symbol>> = [],
        modules:Set<Atom<Module>> = [],
        overlays:Set<Diacritic> = [])
    {
        self.articles = articles
        self.symbols = symbols
        self.modules = modules
        self.overlays = overlays
    }
}
