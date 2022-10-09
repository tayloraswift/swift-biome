import SymbolSource

struct ModuleInterface 
{
    let articles:[Atom<Article>.Position?]
    let symbols:SymbolPositions
    let context:ModuleUpdateContext

    // this does not belong here! once AOT article rendering lands in the `SymbolGraphs` module, 
    // we can get rid of it
    let _cachedMarkdown:[Extension]

    init(context:ModuleUpdateContext, 
        _extensions:[Extension],
        articles:[Atom<Article>.Position?],
        symbols:SymbolPositions)
    {
        self.context = context
        self.symbols = symbols
        self.articles = articles
        self._cachedMarkdown = _extensions
    }

    var citizens:SymbolCitizens
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
