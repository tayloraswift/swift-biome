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
    func render(code:[SwiftLanguage.Lexeme]) -> [Frontend] 
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
    static 
    func render(symbol:Graph.Symbol, 
        dereference:(Graph.Index) -> Graph.Symbol, 
        resolve:(Graph.Symbol.ID) -> String?) -> Frontend
    {
        Frontend[.div]
        {
            Frontend[.div]
            {
                ["upper"]
            }
            content: 
            {
                Frontend[.div]
                {
                    ["upper-container"]
                }
                content: 
                {
                    Frontend[.article]
                    {
                        ["upper-container-left"]
                    }
                    content: 
                    {
                        Frontend[.section]
                        {
                            ["introduction"]
                        }
                        content:
                        {
                            Frontend[.p]
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
                            Frontend[.p]
                            {
                                "Blurb goes here."
                            }
                        }
                        Frontend[.section]
                        {
                            ["declaration"]
                        }
                        content:
                        {
                            Frontend[.h2]
                            {
                                "Declaration"
                            }
                            Frontend[.pre]
                            {
                                Frontend[.code] 
                                {
                                    ["swift"]
                                }
                                content: 
                                {
                                    Self.render(code: symbol.declaration)
                                }
                            }
                        }
                        Frontend[.section]
                        {
                            ["discussion"]
                        }
                        content: 
                        {
                            Frontend[.h2]
                            {
                                "Overview"
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
            Frontend[.div]
            {
                ["lower"]
            }
            content: 
            {
                Frontend[.div]
                {
                    ["lower-container"]
                }
                content:
                {
                    Frontend[.section]
                    {
                        ["topics"]
                    }
                    content: 
                    {
                        Frontend[.h2]
                        {
                            "Topics"
                        }
                        for (topic, members):(Entrapta.Topic, [Graph.Index]) in symbol.topics 
                        {
                            Frontend[.div]
                            {
                                ["topic-container"]
                            }
                            content:
                            {
                                Frontend[.div]
                                {
                                    ["topic-container-left"]
                                }
                                content:
                                {
                                    Frontend[.h3]
                                    {
                                        topic.description
                                    }
                                }
                                Frontend[.ul]
                                {
                                    ["topic-container-right"]
                                }
                                content:
                                {
                                    for member:Graph.Symbol in members.map(dereference)
                                    {
                                        Frontend[.li]
                                        {
                                            ["member"]
                                        }
                                        content: 
                                        {
                                            Frontend[.code]
                                            {
                                                ["signature"]
                                            }
                                            content: 
                                            {
                                                Frontend[.a]
                                                {
                                                    (member.path.canonical, as: Document.HTML.Href.self)
                                                }
                                                content: 
                                                {
                                                    Self.render(code: member.signature)
                                                }
                                            }
                                        }
                                    } 
                                }
                            }
                        }
                    }
                    Frontend[.div]
                    {
                        ["section-container"]
                    }
                    content: 
                    {
                        
                        
                    }
                }
            }

        }
    }
    static 
    func render(page:Frontend) -> Document.Dynamic<Document.HTML, Anchor> 
    {
        .init 
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
                    ("/entrapta.css", as: Document.HTML.Href.self)
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
                    ["documentation"]
                }
                content: 
                {
                    page
                }
            }
        }
    }
    
    public 
    enum Response 
    {
        case canonical(Document.Dynamic<Document.HTML, Anchor>)
        case found(String)
    }
    
    public 
    struct Documentation:Sendable
    {
        typealias Index = Dictionary<Graph.Symbol.Path, Frontend>.Index 
        
        var pages:[Graph.Symbol.Path: Frontend]
        var disambiguations:[Graph.Symbol.ID: Index]
        
        public 
        init(symbolgraphs:[[UInt8]], prefix:String) throws 
        {
            let prefix:String   = prefix.lowercased()
            let json:[JSON]     = try symbolgraphs.map 
            {
                try Grammar.parse($0, as: JSON.Rule<Array<UInt8>.Index>.Root.self)
            }
            let graph:Graph     = try .init(prefix: prefix, modules: json)
            self.init(graph: graph, prefix: prefix)
        }
        
        init(graph:Graph, prefix:String)
        {
            // paths are always unique at this point 
            let pages:[Graph.Symbol.Path: Frontend] = .init(uniqueKeysWithValues: 
                graph.symbols.values.map
            {
                (symbol:Graph.Symbol) -> (key:Graph.Symbol.Path, value:Frontend) in 
                (
                    symbol.path, 
                    Entrapta.render(symbol: symbol)
                    {
                        graph[$0]
                    }
                    resolve: 
                    {
                        graph.symbols[$0].map(\.path.canonical)
                    } 
                )
            })
            self.disambiguations = .init(uniqueKeysWithValues: graph.symbols.map 
            {
                guard let index:Index = pages.index(forKey: $0.value.path)
                else 
                {
                    fatalError("unreachable")
                }
                return ($0.key, index)
            })
            self.pages = _move(pages)
        }
        
        public 
        subscript(group:String, disambiguation disambiguation:String?) -> Response?
        {
            let key:Graph.Symbol.ID?    = disambiguation.map(Graph.Symbol.ID.declaration(precise:))
            let normalized:String       = group.lowercased()
            let path:Graph.Symbol.Path  = .init(group: normalized, disambiguation: key)
            if let page:Frontend        = self.pages[path]
            {
                guard normalized == group 
                else 
                {
                    return .found(path.canonical)
                }
                return .canonical(Entrapta.render(page: page))
            }
            else if let key:Graph.Symbol.ID = key, 
                    let index:Index = self.disambiguations[key]
            {
                return .found(self.pages.keys[index].canonical)
            }
            else 
            {
                return nil
            }
        }
    }
}
