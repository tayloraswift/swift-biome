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
// struct Comments 
// {
//     private(set)
//     var strings:[Symbol.Index: String]
//     private(set)
//     var hints:[Symbol.Index: Symbol.Index]

//     fileprivate 
//     init()
//     {
//         self.strings = [:]
//         self.hints = [:]
//     }

//     fileprivate mutating 
//     func insert(from graph:SymbolGraph, abstractor:Abstractor)
//     {


//         let culture:Package.Index = abstractor.culture.package
//         for hint:SymbolGraph.Hint<Int> in graph.hints
//         {
//             // don’t care about hints for symbols in other packages
//             if  let source:Symbol.Index = abstractor[hint.source],
//                     source.module.package == culture,
//                 let origin:Symbol.Index = abstractor[hint.origin],
//                     origin != source
//             {
//                 self.hints[source] = origin
//             }
//         }
//         // don’t accidentally vacuum up comments inherited from other modules
//         for (index, vertex):(Symbol.Index?, SymbolGraph.Vertex<Int>) in 
//             zip(abstractor.updates, graph.vertices)
//         {
//             if let index:Symbol.Index, !vertex.comment.isEmpty
//             {
//                 self.strings[index] = vertex.comment
//             }
//         }
//     }
//     //  even though pruning is also done at the symbolgraphconvert level, 
//     //  we do another pass here to deduplicate comments *across* modules.
//     //  this is a performance win, because we can skip any hints (and the 
//     //  required string comparisons) that do not cross a culture boundary.
//     fileprivate mutating 
//     func prune() 
//     {
        
//         for (symbol, union):(Symbol.Index, Symbol.Index) in self.hints 
//             where symbol.module != union.module
//         {
//             if  let comment:String  = self.strings[symbol],
//                 let original:String = self.strings[union],
//                     original == comment 
//             {
//                 self.strings.removeValue(forKey: symbol)
                
//             }
//         }
        
//     }
// }