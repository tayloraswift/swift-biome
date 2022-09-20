import SymbolGraphs 

extension Package 
{
    struct Data 
    {
        var topLevelArticles:History<Set<Atom<Article>>>
        var topLevelSymbols:History<Set<Atom<Symbol>>>
        private(set)
        var declarations:History<Declaration<Atom<Symbol>>>

        var standaloneDocumentation:History<DocumentationExtension<Never>>
        var symbolDocumentation:History<DocumentationExtension<Atom<Symbol>>>

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
        for (position, vertex):(PluralPosition<Symbol>?, SymbolGraph.Vertex<Int>) in 
            zip(interface.citizenSymbols, graph.vertices)
        {
            guard let element:Atom<Symbol> = position?.contemporary
            else 
            {
                continue 
            }
            let declaration:Declaration<Atom<Symbol>> = vertex.declaration.flatMap 
            {
                if let target:Atom<Symbol> = interface.symbols[$0]?.contemporary
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
            self.declarations.update(&branch.symbols, at: .declaration(of: element), 
                revision: revision, 
                value: declaration, 
                trunk: trunk)
        }
    }
}