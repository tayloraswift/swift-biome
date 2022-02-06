import StructuredDocument 
import HTML 

extension Entrapta 
{
    struct Documentation 
    {
        typealias Frontend = Document.Element<Document.HTML, Anchor>
        enum Anchor:DocumentID 
        {
            var documentId:String 
            {
                fatalError("unreachable")
            }
        }
        
        var pages:[Symbol.ID: Frontend]
    }
}
extension Entrapta.Documentation 
{
    struct Symbol 
    {
        struct ID:Hashable
        {
            let mangled:String 
        }
        
        let path:[String]
        let content:Frontend
        
        var shortcut:String 
        {
            self.path.map { "/\($0)" }.joined()
        }
    }
    
    init(graph:Graph)
    {
        self.pages = [:]
        for descriptor:Graph.Symbol in graph.symbols 
        {
            // compute URI 
            let path:[String]       = descriptor.path
            let title:String        = descriptor.display.title 
            let id:Symbol.ID        = .init(mangled: descriptor.id)
            let content:Frontend    = Frontend[.article]
            {
                Frontend[.h1] 
                {
                    title 
                }
            }
            self.pages[id] = content 
        }
    }
}
