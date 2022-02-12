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
    func render(code:[Language.Lexeme], resolve:(Graph.Symbol.ID) -> Graph.Symbol?) 
        -> [Frontend] 
    {
        code.map 
        {
            switch $0 
            {
            case .code(let text, class: let classification):
                let css:String
                switch classification 
                {
                case .punctuation: 
                    return Frontend.text(escaping: text)
                case .type(let id?):
                    guard let resolved:Graph.Symbol = resolve(id)
                    else 
                    {
                        fallthrough
                    }
                    return Frontend.link(text, to: resolved.path.canonical, internal: true)
                    {
                        ["syntax-type"] 
                    }
                case .type(nil):
                    css = "syntax-type"
                case .identifier:
                    css = "syntax-identifier"
                case .generic:
                    css = "syntax-generic"
                case .argument:
                    css = "syntax-parameter-label"
                case .parameter:
                    css = "syntax-parameter-name"
                case .directive, .keyword, .attribute:
                    css = "syntax-keyword"
                case .pseudo:
                    css = "syntax-pseudo-identifier"
                case .number, .string:
                    css = "syntax-literal"
                case .interpolation:
                    css = "syntax-interpolation-anchor"
                case .macro:
                    css = "syntax-macro"
                }
                return Frontend.span(text)
                {
                    [css]
                }
            case .comment(let text, documentation: _):
                return Frontend.span(text)
                {
                    ["syntax-comment"]
                } 
            case .invalid(let text):
                return Frontend.span(text)
                {
                    ["syntax-invalid"]
                } 
            case .newlines(let count):
                return Frontend.span(String.init(repeating: "\n", count: count))
                {
                    ["syntax-newline"]
                } 
            case .spaces(let count):
                return Frontend.text(escaped: String.init(repeating: " ", count: count)) 
            }
        }
    }
    static 
    func render(navigation symbol:Graph.Symbol, 
        dereference:(Graph.Index) -> Graph.Symbol) -> Frontend
    {
        let tail:Frontend           = Frontend[.li]
        {
            symbol.breadcrumbs.tail 
        }
        var breadcrumbs:[Frontend]  = [tail]
        var next:Graph.Index?       = symbol.parent
        while let index:Graph.Index = next 
        {
            let parent:Graph.Symbol = dereference(index)
            breadcrumbs.append(Frontend[.li]
            {
                Frontend.link(parent.breadcrumbs.tail, to: parent.path.canonical, internal: true)
            })
            next = parent.parent
        }
        return Frontend[.nav]
        {
            Frontend[.ol] 
            {
                ["breadcrumbs-container"]
            }
            content:
            {
                // github icon 
                /* Frontend[.li]
                {
                    ["github-icon-container"]
                }
                {
                    HTML.element("a", ["href": github])
                    {
                        HTML.element("span", ["class": "github-icon", "title": "Github repository"])
                    }
                } */
                breadcrumbs.reversed()
            }
        }
    }
    static 
    func render(symbol:Graph.Symbol, 
        dereference:(Graph.Index) -> Graph.Symbol, 
        resolve:(Graph.Symbol.ID) -> Graph.Symbol?) -> Frontend
    {
        let discussion:(head:Frontend?, body:[Frontend]) 
        if let comment:String = symbol.comment 
        {
            discussion = Self.render(markdown: comment)
            {
                (path:String?) in 
                Frontend[.code]
                {
                    path ?? "<unknown>"
                }
            }
            link: 
            {
                (target:String?, content:[Frontend]) in 
                if let target:String = target
                {
                    return Frontend[.a]
                    {
                        (target, as: Document.HTML.Href.self)
                        Document.HTML.Target._blank
                        Document.HTML.Rel.nofollow
                    }
                    content:
                    {
                        content
                    }
                }
                else 
                {
                    return Frontend[.span]
                    {
                        content
                    }
                }
            }
            image: 
            {
                (source:String?, alt:[Frontend], title:String?) in 
                if let source:String = source
                {
                    return Frontend[.img]
                    {
                        (source, as: Document.HTML.Src.self)
                    }
                }
                else 
                {
                    return Frontend[.img]
                }
            }
            highlight: 
            {
                (code:String) in 
                Frontend[.pre]
                {
                    Frontend[.code]
                    {
                        Self.render(code: Language.highlight(code: code), resolve: resolve)
                    }
                }
            }
        }
        else 
        {
            discussion = (nil, [])
        }
        return Frontend[.main]
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
                            if let head:Frontend = discussion.head 
                            {
                                head
                            }
                            else 
                            {
                                Frontend[.p]
                                {
                                    "No overview available."
                                }
                            }
                            if symbol.isRequirement 
                            {
                                Frontend[.p]
                                {
                                    ["requirement"]
                                }
                                content:
                                {
                                    "Required."
                                }
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
                                    Self.render(code: symbol.declaration, resolve: resolve)
                                }
                            }
                        }
                        Frontend[.section]
                        {
                            ["discussion"]
                        }
                        content: 
                        {
                            discussion.body
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
                                                    Self.render(code: member.signature){ _ in nil }
                                                }
                                            }
                                        }
                                    } 
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    static 
    func render(page symbol:Graph.Symbol, 
        dereference:(Graph.Index) -> Graph.Symbol, 
        resolve:(Graph.Symbol.ID) -> Graph.Symbol?) 
        -> Document.Dynamic<Document.HTML, Anchor> 
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
                ["documentation"]
            }
            content: 
            {
                Self.render(navigation: symbol, dereference: dereference)
                Self.render(symbol: symbol, dereference: dereference, resolve: resolve)
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
        typealias Index = Dictionary<Graph.Symbol.Path, Document.Dynamic<Document.HTML, Anchor>>.Index 
        
        var pages:[Graph.Symbol.Path: Document.Dynamic<Document.HTML, Anchor>]
        var disambiguations:[Graph.Symbol.ID: Index]
        
        public 
        init(symbolgraphs:[[UInt8]], prefix:[String]) throws 
        {
            let prefix:[String] = prefix.map{ $0.lowercased() }
            let json:[JSON]     = try symbolgraphs.map 
            {
                try Grammar.parse($0, as: JSON.Rule<Array<UInt8>.Index>.Root.self)
            }
            print("parsed JSON")
            let graph:Graph     = try .init(prefix: prefix, modules: json)
            self.init(graph: graph, prefix: prefix)
        }
        
        init(graph:Graph, prefix:[String]) 
        {
            // paths are always unique at this point 
            let pages:[Graph.Symbol.Path: Document.Dynamic<Document.HTML, Anchor>] = 
                .init(uniqueKeysWithValues: graph.symbols.values.map
            {
                (symbol:Graph.Symbol) -> (key:Graph.Symbol.Path, value:Document.Dynamic<Document.HTML, Anchor>) in 
                (
                    symbol.path, 
                    Entrapta.render(page: symbol)
                    {
                        graph[$0]
                    }
                    resolve: 
                    {
                        graph.symbols[$0]
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
            if let page:Document.Dynamic<Document.HTML, Anchor> = self.pages[path]
            {
                guard normalized == group 
                else 
                {
                    return .found(path.canonical)
                }
                return .canonical(page)
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
