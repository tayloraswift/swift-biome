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
    func updateMetadata(context:__owned PackageUpdateContext, commit:__owned Commit,
        branch:Version.Branch, 
        graphs:[SymbolGraph],
        stems:inout Route.Stems, 
        api:inout SurfaceBuilder) -> PackageInterface
    {
        var interface:PackageInterface = .init(capacity: graphs.count, 
            version: self.tree.commit(commit, to: branch, pins: context.pins()),
            local: context.local)
        for (graph, context):(SymbolGraph, ModuleUpdateContext) in zip(graphs, _move context)
        {
            let interface:ModuleInterface = interface.update(&self.tree[branch], with: graph, 
                context: context, 
                stems: &stems)

            api.update(with: graph.edges, interface: interface, local: self)
        }

        self.tree[branch].routes.stack(routes: api.routes.atomic, 
            revision: interface.revision)
        self.tree[branch].routes.stack(routes: api.routes.compound.joined(), 
            revision: interface.revision)

        api.inferScopes(for: &self.tree[branch], fasces: interface.local, stems: stems)

        self.metadata.update(&self.tree[interface.version.branch], 
            interface: interface, 
            builder: api)
        
        return interface
    }
}
extension Package 
{
    mutating 
    func updateData(literature:__owned Literature,
        interface:__owned PackageInterface, 
        graphs:__owned [SymbolGraph])
    {
        let version:Version = interface.version
        for (graph, interface):(SymbolGraph, ModuleInterface) in zip(graphs, interface)
        {
            self.updateData(to: version, interface: interface, graph: graph) 
        }

        for (element, documentation):(Atom<Module>, DocumentationExtension<Never>)
            in literature.modules 
        {
            self.data.standaloneDocumentation.update(&self.tree[version.branch].modules, 
                at: .documentation(of: element), 
                revision: version.revision, 
                value: documentation, 
                trunk: interface.local.modules)
        }
        for (element, documentation):(Atom<Article>, DocumentationExtension<Never>)
            in literature.articles 
        {
            self.data.standaloneDocumentation.update(&self.tree[version.branch].articles, 
                at: .documentation(of: element), 
                revision: version.revision, 
                value: documentation, 
                trunk: interface.local.articles)
        }
        for (element, documentation):(Atom<Symbol>, DocumentationExtension<Atom<Symbol>>)
            in literature.symbols 
        {
            self.data.symbolDocumentation.update(&self.tree[version.branch].symbols, 
                at: .documentation(of: element), 
                revision: version.revision, 
                value: documentation, 
                trunk: interface.local.symbols)
        }
    }

    private mutating 
    func updateData(to version:Version, interface:ModuleInterface, graph:SymbolGraph)
    {
        self.data.updateDeclarations(&self.tree[version.branch], to: version.revision, 
            interface: interface, 
            graph: graph, 
            trunk: interface.local.symbols)
        

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
            trunk: interface.local.modules)
        

        let topLevelArticles:Set<Atom<Article>> = 
            .init(interface.citizenArticles.lazy.compactMap { $0?.atom })
        self.data.topLevelArticles.update(&self.tree[version.branch].modules, 
            at: .topLevelArticles(of: interface.culture), 
            revision: version.revision, 
            value: _move topLevelArticles, 
            trunk: interface.local.modules)
    }
}