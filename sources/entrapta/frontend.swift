import StructuredDocument 
import HTML 
import JSON

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
    
    static 
    func render(code:[SwiftLanguage.Lexeme]) -> Frontend 
    {
        Frontend[.code] 
        {
            code.map 
            {
                let classes:[String]
                switch $0.kind 
                {
                case .text: 
                    return Frontend.text(escaped: $0.text)
                case .type, .generic:
                    classes = ["syntax-type"] 
                case .attribute, .keyword:
                    classes = ["syntax-keyword"]
                case .number, .string: 
                    classes = ["syntax-literal"]
                case .identifier, .label, .parameter: 
                    classes = ["syntax-identifier"]
                }
                return Frontend.span($0.text)
                {
                    classes
                }
            }
        }
    }
    static 
    func render(_ symbol:Symbol) -> Frontend
    {
        Frontend[.article]
        {
            Frontend[.section]
            {
                ["introduction"]
            }
            content:
            {
                Frontend[.div]
                {
                    ["section-container"]
                }
                content:
                {
                    Frontend[.div]
                    {
                        ["eyebrow"]
                    }
                    content:
                    {
                        symbol.kind.description
                    }
                    Frontend[.h1]
                    {
                        symbol.title
                    }
                    /* if self.blurb.isEmpty 
                    {
                        Frontend[.p]
                        {
                            ["topic-blurb"]
                        }
                        content:
                        {
                            "No overview available"
                        }
                    }
                    else 
                    {
                        self.blurb.html(["class": "topic-blurb"])
                    }
                    if !self.discussion.relationships.isEmpty
                    {
                        for (relationship, _):(Paragraph, Context) in 
                            self.discussion.relationships
                        {
                            relationship.html(["class": "topic-relationships"])
                        }
                    } */
                }
            }
            Frontend[.section]
            {
                Frontend[.div]
                {
                    ["section-container"]
                }
                content: 
                {
                    Frontend[.h2]
                    {
                        "Declaration"
                    }
                    Frontend[.div]
                    {
                        ["declaration-container"]
                    }
                    content:
                    {
                        Self.render(code: symbol.declaration)
                    }
                    
                    Frontend[.h2]
                    {
                        "Discussion"
                    }
                    Frontend[.pre]
                    {
                        Frontend[.code]
                        {
                            symbol.discussion
                        }
                    }
                }
            }
        }
    }
    
    public 
    struct Documentation:Sendable
    {
        public 
        var pages:[String: Frontend]
        
        init(graph:Graph)
        {
            let symbols:[String: Symbol] = .init(graph.symbols.map { ($0.id, .init($0)) }){ $1 }
            self.pages = symbols.mapValues(Entrapta.render(_:))
        }
        
        public 
        subscript(symbol:String?, module module:String) -> Document.Dynamic<Document.HTML, Anchor>?
        {
            let page:Frontend
            if let symbol:String = symbol 
            {
                guard let found:Frontend = self.pages[symbol]
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
                        for symbol:String in self.pages.keys
                        {
                            Frontend[.li]
                            {
                                if let mangled:String = try? Grammar.parse(symbol.unicodeScalars, as: Demangle.Rule<String.Index>.MangledName.self)
                                {
                                    Frontend.link(Demangle[mangled], to: "/reference/\(module)?symbol=\(symbol)")
                                }
                                else 
                                {
                                    Frontend.link(symbol, to: "/reference/\(module)?symbol=\(symbol)")
                                }
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
