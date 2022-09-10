import SymbolGraphs 

struct Literature 
{
    let articles:[(Branch.Position<Article>, Article.Template<Ecosystem.Link>)]
    let symbols:[(Branch.Position<Symbol>, Documentation<Article.Template<Ecosystem.Link>, Symbol.Index>)]
    let modules:[(Branch.Position<Module>, Article.Template<Ecosystem.Link>)]

    init(compiling graphs:__owned [SymbolGraph], 
        interfaces:__owned [ModuleInterface], 
        fasces:__owned Fasces)
    {
        guard let culture:Package.Index = interfaces.first?.culture.package 
        else 
        {
            //return [:]
            fatalError("unimplemented")
        }

        var pruned:Int = 0
        var comments:[Tree.Position<Symbol>: Documentation<String, Tree.Position<Symbol>>] = [:]
        for (graph, interface):(SymbolGraph, ModuleInterface) in zip(_move graphs, interfaces)
        {
            for (position, vertex):(Tree.Position<Symbol>?, SymbolGraph.Vertex<Int>) in 
                zip(interface.citizenSymbols, graph.vertices)
            {
                guard   let position:Tree.Position<Symbol>,
                        let documentation:Documentation<String, Tree.Position<Symbol>> = 
                            vertex.documentation?.flatMap({ interface.symbols[$0] })
                else 
                {
                    continue 
                }
                if  case .extends(let origin?, with: let comment) = documentation, 
                        origin.contemporary.culture != interface.culture,
                    case .extends(_, with: comment)? = comments[origin]
                {
                    // inherited a comment from a *different* module. 
                    // if it were from the same module, symbolgraphconvert 
                    // should have deleted it. 
                    comments[position] = .inherits(origin)
                    pruned += 1
                }
                else 
                {
                    comments[position] = documentation
                }
            }

            for (position, _extension):(Tree.Position<Article>?, Extension) in 
                zip(interface.citizenArticles, interface._extensions)
            {
                // TODO: handle merge behavior block directive 
            }
        }
        if pruned != 0 
        {
            print("pruned \(pruned) duplicate comments")
        }

        var skipped:Int = 0,
            dropped:Int = 0
        comments = comments.compactMapValues 
        {
            if case .inherits(var origin) = $0 
            {
                // fast-forward until we either reach a package boundary, 
                // or a local symbol that has documentation
                var visited:Set<Branch.Position<Symbol>> = []
                fastforwarding:
                while origin.package == culture
                {
                    if  case _? = visited.update(with: origin.contemporary)
                    {
                        fatalError("detected cycle in doccomment inheritance graph")
                    }
                    switch comments[origin] 
                    {
                    case nil: 
                        dropped += 1
                        return nil 
                    case .extends(_, with: _)?: 
                        break fastforwarding
                    case .inherits(let next)?: 
                        origin = next 
                        skipped += 1
                    }
                }
                return .inherits(origin)
            }
            else 
            {
                return $0
            }
        }
        if skipped != 0 
        {
            print("shortened \(skipped) doccomment inheritance links")
        }
        if dropped != 0 
        {
            print("pruned \(dropped) nil-terminating doccomment inheritance chains")
        }
        //return comments 
        fatalError("unimplemented")
    }
}