import SymbolGraphs 

extension Sequence<SymbolGraph> 
{
    func generateComments(abstractors:[Abstractor]) -> Comments
    {
        var comments:Comments = .init()
        for (graph, abstractor):(SymbolGraph, Abstractor) in zip(self, abstractors)
        {
            comments.insert(from: graph, abstractor: abstractor)
        }
        comments.integrate()
        return comments
    }
}
struct Comments 
{
    private(set)
    var strings:[Symbol.Index: String]
    private(set)
    var uptree:[Symbol.Index: Symbol.Index]

    fileprivate 
    init()
    {
        self.strings = [:]
        self.uptree = [:]
    }

    fileprivate mutating 
    func insert(from graph:SymbolGraph, abstractor:Abstractor)
    {
        let culture:Package.Index = abstractor.culture.package
        for hint:SymbolGraph.Hint<Int> in graph.hints
        {
            // don’t care about hints for symbols in other packages
            if  let source:Symbol.Index = abstractor[hint.source],
                    source.module.package == culture,
                let origin:Symbol.Index = abstractor[hint.origin],
                    origin != source
            {
                self.uptree[source] = origin
            }
        }
        // don’t accidentally vacuum up comments inherited from other modules
        for (index, vertex):(Symbol.Index?, SymbolGraph.Vertex<Int>) in 
            zip(abstractor.updates, graph.vertices)
        {
            if let index:Symbol.Index, !vertex.comment.isEmpty
            {
                self.strings[index] = vertex.comment
            }
        }
    }
    fileprivate mutating 
    func integrate()
    {
        // flatten the uptree, in O(n). every item in the dictionary will be 
        // visited at most twice.
        for index:Dictionary<Symbol.Index, Symbol.Index>.Index in self.uptree.indices 
        {
            var crumbs:Set<Dictionary<Symbol.Index, Symbol.Index>.Index> = []
            var current:Dictionary<Symbol.Index, Symbol.Index>.Index = index
            while let union:Dictionary<Symbol.Index, Symbol.Index>.Index = 
                self.uptree.index(forKey: self.uptree.values[current])
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
                self.uptree.values[crumb] = self.uptree.values[current]
            }
        }
        self.prune()
    }
    private mutating 
    func prune() 
    {
        // delete comments if a hint indicates it is duplicated
        var pruned:Int = 0
        for (symbol, union):(Symbol.Index, Symbol.Index) in self.uptree 
        {
            if  let comment:String  = self.strings[symbol],
                let original:String = self.strings[union],
                    original == comment 
            {
                self.strings.removeValue(forKey: symbol)
                pruned += 1
            }
        }
        print("pruned \(pruned) duplicate comments")
    }
}