import SymbolGraphs 
import DOM
import URI

enum ExpandedLink:Hashable, Sendable 
{
    case article(Tree.Position<Article>)
    case package(Package.Index)
    case implicit                        ([Tree.Position<Symbol>])
    case qualified(Tree.Position<Module>, [Tree.Position<Symbol>] = [])
}
enum ResolvedLink:Hashable, Sendable 
{
    case article(Branch.Position<Article>)
    case module(Branch.Position<Module>)
    case package(Package.Index)
    case composite(Branch.Composite)
}

struct Literature 
{
    struct Compiled 
    {
        struct Link:Hashable, Sendable
        {
            let target:ResolvedLink
            let visible:Int
            
            init(_ target:ResolvedLink, visible:Int)
            {
                self.target = target 
                self.visible = visible
            }
        }
        
        let errors:[any Error]
        let card:DOM.Flattened<Link>
        let body:DOM.Flattened<Link>
    }

    let articles:[(Branch.Position<Article>, Compiled)]
    let symbols:[(Branch.Position<Symbol>, Documentation<Compiled, Symbol.Index>)]
    let modules:[(Branch.Position<Module>, Compiled)]

    init(compiling graphs:__owned [SymbolGraph], 
        interfaces:__owned [ModuleInterface], 
        version:_Version, 
        context:__shared Packages, 
        stems:__shared Route.Stems)
    {
        guard let culture:Package.Index = interfaces.first?.culture.package 
        else 
        {
            //return [:]
            fatalError("unimplemented")
        }

        let local:Package._Pinned = .init(context[culture], version: version)

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


            let upstream:[Package._Pinned] = interface.pins.map 
            {
                .init(context[$0.key], version: $0.value)
            }

            for (position, _extension):(Tree.Position<Article>?, Extension) in 
                zip(interface.citizenArticles, interface._extensions)
            {
                // TODO: handle merge behavior block directive 
                if let position:Tree.Position<Article> 
                {

                }
                // else if let binding:String = _extension.binding, 
                //         let binding:URI = try? .init(relative: binding), 
                //     case .one(let binding)? = try? local._resolve(binding, stems: stems)
                // {
                    
                // }
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