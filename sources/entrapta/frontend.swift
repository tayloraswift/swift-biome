import StructuredDocument 
import HTML 

extension Entrapta 
{
    public 
    typealias Frontend = Document.Element<Document.HTML, Anchor>
    
    public 
    enum Anchor:DocumentID 
    {
        public 
        var documentId:String 
        {
            fatalError("unreachable")
        }
    }
    public 
    struct Symbol 
    {
        public 
        struct ID:Hashable
        {
            let mangled:String 
        }
        
        public 
        let path:[String], 
            content:Frontend
        
        var shortcut:String 
        {
            self.path.map { "/\($0)" }.joined()
        }
    }
    public 
    struct Documentation 
    {
        public 
        var pages:[Symbol.ID: Frontend]
        
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
}
