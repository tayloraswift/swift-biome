import SymbolGraphs 

extension Package 
{
    struct Data 
    {
        var topLevelArticles:History<Set<Branch.Position<Article>>>
        var topLevelSymbols:History<Set<Branch.Position<Symbol>>>
        private(set)
        var declarations:History<Declaration<Branch.Position<Symbol>>>

        var standaloneDocumentation:History<DocumentationExtension<Never>>
        var symbolDocumentation:History<DocumentationExtension<Branch.Position<Symbol>>>

        init() 
        {
            self.topLevelArticles = .init()
            self.topLevelSymbols = .init()
            self.declarations = .init()

            self.standaloneDocumentation = .init()
            self.symbolDocumentation = .init()
        }
    }
}

extension Package.Data 
{
    mutating 
    func updateDeclarations(_ branch:inout Branch, 
        to revision:Version.Revision, 
        interface:ModuleInterface, 
        graph:SymbolGraph, 
        trunk:some Sequence<Epoch<Symbol>>)
    {
        for (position, vertex):(Tree.Position<Symbol>?, SymbolGraph.Vertex<Int>) in 
            zip(interface.citizenSymbols, graph.vertices)
        {
            guard let position:Branch.Position<Symbol> = position?.contemporary
            else 
            {
                continue 
            }
            let declaration:Declaration<Branch.Position<Symbol>> = vertex.declaration.flatMap 
            {
                if let target:Branch.Position<Symbol> = interface.symbols[$0]?.contemporary
                {
                    return target 
                }
                // ignore warnings related to c-language symbols 
                let id:Symbol.ID = graph.identifiers[$0]
                if case .swift = id.language 
                {
                    print("warning: unknown id '\(id)' (in declaration for symbol '\(vertex.path)')")
                }
                return nil
            }
            self.declarations.update(&branch.symbols, position: position, with: declaration, 
                revision: revision, 
                field: (\.declaration, \.declaration),
                trunk: trunk)
        }
    }
}