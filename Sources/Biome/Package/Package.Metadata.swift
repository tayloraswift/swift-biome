extension Package 
{
    struct Metadata 
    {
        private(set)
        var articles:_History<Article.Metadata?>,
            modules:_History<Module.Metadata?>, 
            symbols:_History<Symbol.Metadata?>, 
            foreign:_History<Symbol.ForeignMetadata?>

        init() 
        {
            self.articles = .init()
            self.modules = .init()
            self.symbols = .init()
            self.foreign = .init()
        }
    }
}

extension Package.Metadata 
{
    mutating 
    func update(_ branch:inout Branch, to revision:_Version.Revision, 
        interfaces:[ModuleInterface], 
        surface:Surface, 
        fasces:Fasces)
    {
        for missing:Branch.Position<Module> in surface.missingModules 
        {
            self.modules.update(&branch.modules, position: missing, with: nil, 
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: fasces.modules)
        }
        for missing:Branch.Position<Article> in surface.missingArticles 
        {
            self.articles.update(&branch.articles, position: missing, with: nil, 
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: fasces.articles)
        }
        for missing:Branch.Position<Symbol> in surface.missingSymbols 
        {
            self.symbols.update(&branch.symbols, position: missing, with: nil, 
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: fasces.symbols)
        }
        for missing:Branch.Diacritic in surface.missingHosts 
        {
            self.foreign.update(&branch.foreign, key: missing, with: nil, 
                revision: revision, 
                field: \.metadata,
                trunk: fasces.foreign)
        }
        
        for interface:ModuleInterface in interfaces 
        {
            self.modules.update(&branch.modules, position: interface.culture, 
                with: .init(namespaces: interface.namespaces), 
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: fasces.modules)
        }
        for (article, metadata):(Branch.Position<Article>, Article.Metadata) in 
            surface.articles
        {
            self.articles.update(&branch.articles, position: article, 
                with: metadata,
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: fasces.articles) 
        }
        for (symbol, facts):(Tree.Position<Symbol>, Symbol.Facts<Tree.Position<Symbol>>) in 
            surface.local
        {
            self.symbols.update(&branch.symbols, position: symbol.contemporary, 
                with: .init(facts: facts),
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: fasces.symbols) 
        }
        for (diacritic, traits):(Tree.Diacritic, Symbol.Traits<Tree.Position<Symbol>>) in 
            surface.foreign
        {
            self.foreign.update(&branch.foreign, key: diacritic.contemporary, 
                with: .init(traits: traits), 
                revision: revision, 
                field: \.metadata, 
                trunk: fasces.foreign)
        }
    }
}