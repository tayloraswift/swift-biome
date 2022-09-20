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
        for missing:Atom<Module> in builder.previous.modules 
        {
            self.modules.update(&branch.modules, at: .metadata(of: missing), 
                revision: revision, 
                value: nil, 
                trunk: fasces.modules)
        }
        for missing:Atom<Article> in builder.previous.articles 
        {
            self.articles.update(&branch.articles, at: .metadata(of: missing), 
                revision: revision, 
                value: nil,
                trunk: fasces.articles)
        }
        for missing:Atom<Symbol> in builder.previous.symbols
        {
            self.symbols.update(&branch.symbols, at: .metadata(of: missing), 
                revision: revision, 
                value: nil, 
                trunk: fasces.symbols)
        }
        for missing:Diacritic in builder.previous.foreign 
        {
            self.foreign.update(&branch.foreign, at: .metadata(of: missing),
                revision: revision, 
                value: nil, 
                trunk: fasces.foreign)
        }
        
        for interface:ModuleInterface in interfaces 
        {
            self.modules.update(&branch.modules, at: .metadata(of: interface.culture), 
                revision: revision, 
                value: .init(namespaces: interface.namespaces), 
                trunk: fasces.modules)
        }
        for (article, metadata):(Atom<Article>, Article.Metadata) in 
            builder.articles
        {
            self.articles.update(&branch.articles, at: .metadata(of: article), 
                revision: revision, 
                value: metadata,
                trunk: fasces.articles) 
        }
        for (symbol, metadata):(Atom<Symbol>, Symbol.Metadata) in 
            builder.symbols
        {
            self.symbols.update(&branch.symbols, at: .metadata(of: symbol), 
                revision: revision, 
                value: metadata,
                trunk: fasces.symbols) 
        }
        for (diacritic, metadata):(Diacritic, Symbol.ForeignMetadata) in 
            builder.foreign
        {
            self.foreign.update(&branch.foreign, at: .metadata(of: diacritic), 
                revision: revision, 
                value: metadata, 
                trunk: fasces.foreign)
        }
    }
}