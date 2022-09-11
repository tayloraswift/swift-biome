extension Package 
{
    struct Metadata 
    {
        private(set)
        var modules:_History<Module.Metadata?>, 
            symbols:_History<Symbol.Metadata?>, 
            foreign:_History<Symbol.ForeignMetadata?>

        init() 
        {
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
        self.update(&branch.modules, missing: surface.missingModules, revision: revision, 
            trunk: fasces.modules)
        self.update(&branch.symbols, missing: surface.missingSymbols, revision: revision, 
            trunk: fasces.symbols)
        self.update(&branch.foreign, missing: surface.missingHosts, revision: revision, 
            trunk: fasces.foreign)
        
        for interface:ModuleInterface in interfaces 
        {
            self.modules.update(&branch.modules, position: interface.culture, 
                with: .init(namespaces: interface.namespaces), 
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: fasces.modules)
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

    private mutating 
    func update(_ modules:inout Branch.Buffer<Module>, missing:Set<Branch.Position<Module>>, 
        revision:_Version.Revision, 
        trunk:some Sequence<Epoch<Module>>)
    {
        for missing:Branch.Position<Module> in missing 
        {
            self.modules.update(&modules, position: missing, with: nil, 
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: trunk)
        }
    }
    private mutating 
    func update(_ symbols:inout Branch.Buffer<Symbol>, missing:Set<Branch.Position<Symbol>>, 
        revision:_Version.Revision, 
        trunk:some Sequence<Epoch<Symbol>>)
    {
        for missing:Branch.Position<Symbol> in missing 
        {
            self.symbols.update(&symbols, position: missing, with: nil, 
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: trunk)
        }
    }
    private mutating 
    func update(_ foreign:inout [Branch.Diacritic: Symbol.ForeignDivergence], 
        missing:Set<Branch.Diacritic>, 
        revision:_Version.Revision, 
        trunk:some Sequence<Divergences<Branch.Diacritic, Symbol.ForeignDivergence>>)
    {
        for missing:Branch.Diacritic in missing 
        {
            self.foreign.update(&foreign, key: missing, with: nil, 
                revision: revision, 
                field: \.metadata,
                trunk: trunk)
        }
    }
}