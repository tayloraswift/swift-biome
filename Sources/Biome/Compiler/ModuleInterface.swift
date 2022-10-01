import SymbolSource

struct ModuleInterface 
{
    struct SymbolLookupError:Error 
    {
        let index:Int 

        init(_ index:Int)
        {
            self.index = index
        }
    }

    let context:ModuleUpdateContext
    var articles:Abstractor<Article>
    var symbols:Abstractor<Symbol>

    // this does not belong here! once AOT article rendering lands in the `SymbolGraphs` module, 
    // we can get rid of it
    let _cachedMarkdown:[Extension]

    init(context:ModuleUpdateContext, 
        _extensions:[Extension],
        articles:Abstractor<Article>,
        symbols:Abstractor<Symbol>)
    {
        self.context = context
        self.symbols = symbols
        self.articles = articles
        self._cachedMarkdown = _extensions
    }

    var citizenArticles:Citizens<Article> 
    {
        self.articles.citizens(culture: self.culture)
    }
    var citizenSymbols:Citizens<Symbol> 
    {
        self.symbols.citizens(culture: self.culture)
    }
    var nationality:Packages.Index
    {
        self.context.nationality
    }
    var culture:Atom<Module> 
    {
        self.context.culture 
    }

    var namespaces:Namespaces
    {
        self.context.namespaces
    }
    var local:Fasces
    {
        self.context.local
    }
}
