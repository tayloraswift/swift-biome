import SymbolGraphs 

extension PackageGraph 
{
    func comments(translations:[[Symbol.Index?]], culture:Package.Index) 
        -> [Symbol.Index: String]
    {
        var comments:[Symbol.Index: String] = [:]
        var uptree:[Symbol.Index: Symbol.Index] = [:]
        for (graph, translations):(SymbolGraph, [Symbol.Index?]) in 
            zip(self.modules, translations)
        {
            for hint:SymbolGraph.Hint<Int> in graph.hints
            {
                // don’t care about hints for symbols in other packages
                if  let source:Symbol.Index = translations[hint.source],
                        source.module.package == culture,
                    let origin:Symbol.Index = translations[hint.origin],
                        origin != source
                {
                    uptree[source] = origin
                }
            }
            for (index, vertex):(Symbol.Index?, SymbolGraph.Vertex<Int>) in 
                zip(translations, graph.vertices)
            {
                // don’t accidentally vacuum up comments inherited 
                // from other packages
                if  let index:Symbol.Index, 
                        index.module.package == culture, !vertex.comment.isEmpty
                {
                    comments[index] = vertex.comment
                }
            }
        }

        // flatten the uptree, in O(n). every item in the dictionary will be 
        // visited at most twice.
        for index:Dictionary<Symbol.Index, Symbol.Index>.Index in uptree.indices 
        {
            var crumbs:Set<Dictionary<Symbol.Index, Symbol.Index>.Index> = []
            var current:Dictionary<Symbol.Index, Symbol.Index>.Index = index
            while let union:Dictionary<Symbol.Index, Symbol.Index>.Index = 
                uptree.index(forKey: uptree.values[current])
            {
                assert(current != union)
                
                crumbs.update(with: current)
                current = union
                
                if crumbs.contains(union)
                {
                    fatalError("detected cycle in doccomment uptree")
                }
            }
            for crumb:Dictionary<Symbol.Index, Symbol.Index>.Index in crumbs 
            {
                uptree.values[crumb] = uptree.values[current]
            }
        }
        // delete comments if a hint indicates it is duplicated
        var pruned:Int = 0
        for (member, union):(Symbol.Index, Symbol.Index) in hints 
        {
            if  let comment:String  = comments[member],
                let original:String = comments[union],
                    original == comment 
            {
                comments.removeValue(forKey: member)
                pruned += 1
            }
        }
        print("pruned \(pruned) duplicate comments")
        return comments
    }
}