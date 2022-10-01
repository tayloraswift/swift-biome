extension Package 
{
    enum MetadataLoadingError:Error 
    {
        case article
        case module
        case symbol
        case foreign
    }

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
    func update(_ branch:inout Branch, 
        interface:PackageInterface, 
        builder:SurfaceBuilder)
    {
        for missing:Atom<Module> in builder.previous.modules 
        {
            self.modules.update(&branch.modules, at: .metadata(of: missing), 
                revision: interface.revision, 
                value: nil, 
                trunk: interface.local.modules)
        }
        for missing:Atom<Article> in builder.previous.articles 
        {
            self.articles.update(&branch.articles, at: .metadata(of: missing), 
                revision: interface.revision, 
                value: nil,
                trunk: interface.local.articles)
        }
        for missing:Atom<Symbol> in builder.previous.symbols
        {
            self.symbols.update(&branch.symbols, at: .metadata(of: missing), 
                revision: interface.revision, 
                value: nil, 
                trunk: interface.local.symbols)
        }
        for missing:Diacritic in builder.previous.foreign 
        {
            self.foreign.update(&branch.foreign, at: .metadata(of: missing),
                revision: interface.revision, 
                value: nil, 
                trunk: interface.local.foreign)
        }
        
        for module:ModuleInterface in interface
        {
            self.modules.update(&branch.modules, at: .metadata(of: module.culture), 
                revision: interface.revision, 
                value: .init(dependencies: module.namespaces.dependencies()),
                trunk: interface.local.modules)
        }
        for (article, metadata):(Atom<Article>, Article.Metadata) in 
            builder.articles
        {
            self.articles.update(&branch.articles, at: .metadata(of: article), 
                revision: interface.revision, 
                value: metadata,
                trunk: interface.local.articles) 
        }
        for (symbol, metadata):(Atom<Symbol>, Symbol.Metadata) in 
            builder.symbols
        {
            self.symbols.update(&branch.symbols, at: .metadata(of: symbol), 
                revision: interface.revision, 
                value: metadata,
                trunk: interface.local.symbols) 
        }
        for (diacritic, metadata):(Diacritic, Symbol.ForeignMetadata) in 
            builder.foreign
        {
            self.foreign.update(&branch.foreign, at: .metadata(of: diacritic), 
                revision: interface.revision, 
                value: metadata, 
                trunk: interface.local.foreign)
        }
    }
}