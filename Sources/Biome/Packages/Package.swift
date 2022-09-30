import SymbolGraphs
import SymbolSource
import Versions
import URI 

public 
struct Package:Identifiable, Sendable
{
    public 
    let id:PackageIdentifier
    var settings:Settings 
    
    var name:String 
    {
        self.id.string
    }

    private(set)
    var metadata:Metadata, 
        data:Data 
    var tree:Tree

    init(id:PackageIdentifier, nationality:Packages.Index)
    {
        self.id = id 
        switch id 
        {
        case .swift, .core: 
            self.settings = .init(brand: "Swift")
        case .community(_):
            self.settings = .init()
        }
        
        self.metadata = .init()
        self.data = .init()
        self.tree = .init(nationality: nationality)
    }

    var nationality:Packages.Index 
    {
        self.tree.nationality
    }

    func latest() -> Pinned?
    {
        self.tree.default.map { .init(self, version: $0) }
    }
}

extension Package 
{
    mutating 
    func updateMetadata(to version:Version, 
        interfaces:[ModuleInterface], 
        builder:SurfaceBuilder, 
        fasces:Fasces)
    {
        self.metadata.update(&self.tree[version.branch], to: version.revision, 
            interfaces: interfaces, 
            builder: builder, 
            fasces: fasces)
    }
    mutating 
    func updateData(to version:Version, graph:SymbolGraph, 
        interface:ModuleInterface, 
        fasces:Fasces)
    {
        self.data.updateDeclarations(&self.tree[version.branch], to: version.revision, 
            interface: interface, 
            graph: graph, 
            trunk: fasces.symbols)
        

        var topLevelSymbols:Set<Atom<Symbol>> = [] 
        for position:Atom<Symbol>.Position? in interface.citizenSymbols
        {
            if  let position:Atom<Symbol>.Position, 
                self.tree[local: position].path.prefix.isEmpty
            {
                // a symbol is toplevel if it has a single path component. this 
                // is not the same thing as having a `nil` shape.
                topLevelSymbols.insert(position.atom)
            }
        }
        self.data.topLevelSymbols.update(&self.tree[version.branch].modules, 
            at: .topLevelSymbols(of: interface.culture), 
            revision: version.revision, 
            value: _move topLevelSymbols, 
            trunk: fasces.modules)
        

        let topLevelArticles:Set<Atom<Article>> = 
            .init(interface.citizenArticles.lazy.compactMap { $0?.atom })
        self.data.topLevelArticles.update(&self.tree[version.branch].modules, 
            at: .topLevelArticles(of: interface.culture), 
            revision: version.revision, 
            value: _move topLevelArticles, 
            trunk: fasces.modules)
    }
    mutating 
    func updateDocumentation(to version:Version, literature:__owned Literature, fasces:Fasces)
    {
        for (element, documentation):(Atom<Module>, DocumentationExtension<Never>)
            in literature.modules 
        {
            self.data.standaloneDocumentation.update(&self.tree[version.branch].modules, 
                at: .documentation(of: element), 
                revision: version.revision, 
                value: documentation, 
                trunk: fasces.modules)
        }
        for (element, documentation):(Atom<Article>, DocumentationExtension<Never>)
            in literature.articles 
        {
            self.data.standaloneDocumentation.update(&self.tree[version.branch].articles, 
                at: .documentation(of: element), 
                revision: version.revision, 
                value: documentation, 
                trunk: fasces.articles)
        }
        for (element, documentation):(Atom<Symbol>, DocumentationExtension<Atom<Symbol>>)
            in literature.symbols 
        {
            self.data.symbolDocumentation.update(&self.tree[version.branch].symbols, 
                at: .documentation(of: element), 
                revision: version.revision, 
                value: documentation, 
                trunk: fasces.symbols)
        }
    }
}