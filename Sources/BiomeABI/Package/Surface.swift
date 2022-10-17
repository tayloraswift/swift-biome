@frozen public
struct Surface 
{
    public
    var articles:Set<Article>
    public
    var symbols:Set<Symbol>
    public
    var modules:Set<Module>
    public
    var overlays:Set<Diacritic>

    public
    init(articles:Set<Article> = [],
        symbols:Set<Symbol> = [],
        modules:Set<Module> = [],
        overlays:Set<Diacritic> = [])
    {
        self.articles = articles
        self.symbols = symbols
        self.modules = modules
        self.overlays = overlays
    }
}
