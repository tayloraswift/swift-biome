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
    func updateMetadata(interface:PackageInterface, 
        branch:Version.Branch, 
        graph:SymbolGraph,
        stems:Route.Stems, 
        api:inout SurfaceBuilder)
    {
        for (culture, interface):(SymbolGraph.Culture, ModuleInterface) in 
            zip(graph.cultures, interface)
        {
            api.update(with: culture.edges, interface: interface, local: self)
        }

        self.tree[branch].routes.stack(routes: api.routes.atomic, 
            revision: interface.revision)
        self.tree[branch].routes.stack(routes: api.routes.compound.joined(), 
            revision: interface.revision)

        api.inferScopes(for: &self.tree[branch], fasces: interface.local, stems: stems)

        self.tree[interface.branch].updateMetadata(interface: interface, builder: api)
    }

    mutating 
    func updateData(_ graph:__owned SymbolGraph, 
        interface:PackageInterface)
    {
        let version:Version = interface.version
        for (culture, interface):(SymbolGraph.Culture, ModuleInterface) in 
            zip((_move graph).cultures, interface)
        {
            self.tree[version.branch].updateDeclarations(culture, 
                interface: interface, 
                revision: version.revision)

            var topLevelSymbols:Set<Atom<Symbol>> = [] 
            for position:Atom<Symbol>.Position? in interface.citizens
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
                .init(interface.articles.lazy.compactMap { $0?.atom })
            self.tree[version.branch].updateTopLevelArticles(topLevelArticles, 
                interface: interface,
                revision: version.revision)
        }
    }
    mutating 
    func updateDocumentation(_ documentation:__owned PackageDocumentation,
        interface:PackageInterface)
    {
        self.tree[interface.branch].updateDocumentation(_move documentation, 
            interface: interface)
    }
}