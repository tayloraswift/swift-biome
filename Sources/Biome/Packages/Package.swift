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
    func updateMetadata(interface:PackageInterface, graphs:[SymbolGraph],
        branch:Version.Branch, 
        stems:Route.Stems, 
        api:inout SurfaceBuilder)
    {
        for (graph, interface):(SymbolGraph, ModuleInterface) in zip(graphs, interface)
        {
            api.update(with: graph.edges, interface: interface, local: self)
        }

        self.tree[branch].routes.stack(routes: api.routes.atomic, 
            revision: interface.revision)
        self.tree[branch].routes.stack(routes: api.routes.compound.joined(), 
            revision: interface.revision)

        api.inferScopes(for: &self.tree[branch], fasces: interface.local, stems: stems)

        self.tree[interface.version.branch].updateMetadata(interface: interface, builder: api)
    }

    mutating 
    func updateData(literature:__owned Literature,
        interface:__owned PackageInterface, 
        graphs:__owned [SymbolGraph])
    {
        let version:Version = interface.version

        self.tree[version.branch].updateDocumentation(_move literature, interface: interface)

        for (graph, interface):(SymbolGraph, ModuleInterface) in zip(_move graphs, interface)
        {
            self.tree[version.branch].updateDeclarations(graph: graph, 
                interface: interface, 
                revision: version.revision)

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
            self.tree[version.branch].updateTopLevelSymbols(topLevelSymbols, 
                interface: interface,
                revision: version.revision)
            

            let topLevelArticles:Set<Atom<Article>> = 
                .init(interface.citizenArticles.lazy.compactMap { $0?.atom })
            self.tree[version.branch].updateTopLevelArticles(topLevelArticles, 
                interface: interface,
                revision: version.revision)
        }
    }
}