extension Package 
{
    struct Metadata 
    {
        private(set)
        var modules:_History<Module.Metadata>, 
            symbols:_History<Symbol.Metadata>, 
            foreign:_History<_ForeignMetadata>

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
        //self.update(&branch.opinions, missing: surface.missingDiacritics, revision: revision)
        
        for interface:ModuleInterface in interfaces 
        {
            self.modules.update(&branch.modules, with: interface.metadata(), 
                position: interface.culture, 
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: fasces.modules)
        }
        for (symbol, facts):(Tree.Position<Symbol>, Symbol.Facts<Tree.Position<Symbol>>) in 
            surface.symbols
        {
            self.symbols.update(&branch.symbols, with: facts.metadata(),
                position: symbol.contemporary, 
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: fasces.symbols) 
        }
        for (diacritic, traits):(Tree.Diacritic, Symbol.Traits<Tree.Position<Symbol>>) in 
            surface.diacritics
        {
            let key:Branch.Diacritic = diacritic.contemporary
            let value:_ForeignMetadata = traits.map(\.contemporary) 
            if let previous:_ForeignMetadata = (branch.opinions[key]?.metadata)
                    .map({ self.foreign[$0.head.index].value })
            {
                if previous == value 
                {
                    continue 
                }
            }
            else if case value? = self.foreign.value(of: key, field: \.metadata, 
                in: fasces.lazy.map(\.opinions))
            {
                continue 
            }

            self.foreign.push(value, revision: revision, 
                to: &branch.opinions[key, default: .init()].metadata)
        }
    }

    private mutating 
    func update(_ modules:inout Branch.Buffer<Module>, missing:Set<Branch.Position<Module>>, 
        revision:_Version.Revision, 
        trunk:some Sequence<Branch.Epoch<Module>>)
    {
        for missing:Branch.Position<Module> in missing 
        {
            self.modules.update(&modules, with: .missing, 
                position: missing, 
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: trunk)
        }
    }
    private mutating 
    func update(_ symbols:inout Branch.Buffer<Symbol>, missing:Set<Branch.Position<Symbol>>, 
        revision:_Version.Revision, 
        trunk:some Sequence<Branch.Epoch<Symbol>>)
    {
        for missing:Branch.Position<Symbol> in missing 
        {
            self.symbols.update(&symbols, with: .missing,
                position: missing, 
                revision: revision, 
                field: (\.metadata, \.metadata),
                trunk: trunk)
        }
    }
}