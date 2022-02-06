import StructuredDocument 
import HTML 

extension Entrapta 
{
    public 
    typealias Frontend = Document.Element<Document.HTML, Anchor>
    
    public 
    enum Anchor:DocumentID, Sendable
    {
        public 
        var documentId:String 
        {
            fatalError("unreachable")
        }
    }
    public final
    class Symbol 
    {
        public 
        struct ID:Hashable, Sendable
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
        
        init() 
        {
            fatalError("unreachable")
        }
    }
    public 
    struct Documentation:Sendable
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
        
        public 
        subscript(symbol:String?, module module:String) -> Document.Dynamic<Document.HTML, Anchor>?
        {
            let page:Frontend
            if let mangled:String = symbol 
            {
                guard let found:Frontend = self.pages[.init(mangled: mangled)]
                else 
                {
                    return nil 
                }
                page = found 
            }
            else 
            {
                page = Frontend[.article]
                {
                    Frontend[.p]
                    {
                        "valid symbols:"
                    }
                    Frontend[.ol]
                    {
                        for symbol:Symbol.ID in self.pages.keys
                        {
                            Frontend[.li]
                            {
                                Frontend.link(Demangle["$\(symbol.mangled)"], to: "/reference/\(module)?symbol=\(symbol.mangled)")
                            }
                        }
                    }
                }
            }
            return .init 
            {
                Document.HTML.Lang.en
            }
            content:
            {
                Frontend[.head]
                {
                    Frontend[.title] 
                    {
                        ""
                    }
                    Frontend.metadata(charset: Unicode.UTF8.self)
                    Frontend.metadata 
                    {
                        ("viewport", "width=device-width, initial-scale=1")
                    }
                    
                    Frontend[.link] 
                    {
                        ("https://fonts.googleapis.com", as: Document.HTML.Href.self)
                        Document.HTML.Rel.preconnect 
                    }
                    Frontend[.link] 
                    {
                        Document.HTML.Crossorigin.anonymous 
                        ("https://fonts.gstatic.com", as: Document.HTML.Href.self)
                        Document.HTML.Rel.preconnect 
                    }
                    Frontend[.link] 
                    {
                        ("https://fonts.googleapis.com/css2?family=Literata:ital,wght@0,400;0,600;1,400;1,600&display=swap", as: Document.HTML.Href.self)
                        Document.HTML.Rel.stylesheet 
                    }
                    Frontend[.link]
                    {
                        ("/style.css", as: Document.HTML.Href.self)
                        Document.HTML.Rel.stylesheet
                    }
                    Frontend[.link]
                    {
                        ("/favicon.png", as: Document.HTML.Href.self)
                        Document.HTML.Rel.icon
                    }
                }
                Frontend[.body]
                {
                    Frontend[.main]
                    {
                        page
                    }
                }
            }
        }
    }
}
