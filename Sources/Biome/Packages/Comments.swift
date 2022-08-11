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
        print("pruned \(pruned) duplicate CROSS-MODULE comments")
        return comments
    }
}
