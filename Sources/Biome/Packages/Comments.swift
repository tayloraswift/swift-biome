import SymbolGraphs 

extension Sequence<SymbolGraph> 
{
    //        "abc"                     module C
    //          |
    //  --------|-------------------
    //          ↓            
    //         nil -----→ "abc"         module B
    //                      |
    //  --------------------|-------
    //                      ↓
    //                    "abc"         module A
    func generateComments(abstractors:[Abstractor]) 
        -> [Symbol.Index: Documentation<String, Symbol.Index>]
    {
        guard let culture:Package.Index = abstractors.first?.culture.package 
        else 
        {
            return [:]
        }

        var pruned:Int = 0
        var comments:[Symbol.Index: Documentation<String, Symbol.Index>] = [:]
        for (graph, abstractor):(SymbolGraph, Abstractor) in zip(self, abstractors)
        {
            for (index, vertex):(Symbol.Index?, SymbolGraph.Vertex<Int>) in 
                zip(abstractor.updates, graph.vertices)
            {
                guard   let index:Symbol.Index,
                        let documentation:Documentation<String, Symbol.Index> = 
                            vertex.documentation?.flatMap({ abstractor[$0] })
                else 
                {
                    continue 
                }
                if  case .extends(let origin?, with: let comment) = documentation, 
                        origin.module != abstractor.culture,
                    case .extends(_, with: comment)? = comments[origin]
                {
                    // inherited a comment from a *different* module. 
                    // if it were from the same module, symbolgraphconvert 
                    // should have deleted it. 
                    comments[index] = .inherits(origin)
                    pruned += 1
                }
                else 
                {
                    comments[index] = documentation
                }
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
                var visited:Set<Symbol.Index> = []
                fastforwarding:
                while origin.module.package == culture
                {
                    if  case _? = visited.update(with: origin)
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
        return comments 
    }
}
