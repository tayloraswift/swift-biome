extension Package 
{
    struct Metadata 
    {
        private(set)
        var articles:History<Article.Metadata?>,
            modules:History<Module.Metadata?>, 
            symbols:History<Symbol.Metadata?>, 
            foreign:History<Symbol.ForeignMetadata?>

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
    func update(_ branch:inout Branch, to revision:Version.Revision, 
        interfaces:[ModuleInterface], 
        builder:SurfaceBuilder, 
        fasces:Fasces)
    {
        for missing:Position<Module> in builder.previous.modules 
        {
            self.modules.update(&branch.modules, position: missing, with: nil, 
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: fasces.modules)
        }
        for missing:Position<Article> in builder.previous.articles 
        {
            self.articles.update(&branch.articles, position: missing, with: nil, 
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: fasces.articles)
        }
        for missing:Position<Symbol> in builder.previous.symbols
        {
            self.symbols.update(&branch.symbols, position: missing, with: nil, 
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: fasces.symbols)
        }
        for missing:Diacritic in builder.previous.foreign 
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
        for (article, metadata):(Position<Article>, Article.Metadata) in 
            builder.articles
        {
            self.articles.update(&branch.articles, position: article, with: metadata,
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: fasces.articles) 
        }
        for (symbol, metadata):(Position<Symbol>, Symbol.Metadata) in 
            builder.symbols
        {
            self.symbols.update(&branch.symbols, position: symbol, with: metadata,
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: fasces.symbols) 
        }
        for (diacritic, metadata):(Diacritic, Symbol.ForeignMetadata) in 
            builder.foreign
        {
            self.foreign.update(&branch.foreign, key: diacritic, with: metadata, 
                revision: revision, 
                field: \.metadata, 
                trunk: fasces.foreign)
        }
    }
}