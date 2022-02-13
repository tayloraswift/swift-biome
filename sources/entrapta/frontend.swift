import StructuredDocument 
import HTML 
import JSON

extension Entrapta.Graph.Symbol 
{
    public 
    enum Anchor:DocumentID, Sendable
    {
        public 
        var documentId:String 
        {
            fatalError("unreachable")
        }
    }
}
extension Entrapta.Graph 
{
    public 
    typealias Frontend  = Document.Element<Document.HTML, Symbol.Anchor>
    public 
    typealias Page      = Document.Dynamic<Document.HTML, Symbol.Anchor>
    
    func render(constraint:Language.Constraint) -> [Frontend] 
    {
        let subject:Language.Lexeme = .code(constraint.subject, class: .type(nil))
        let prose:String
        let object:Symbol.ID?
        switch constraint.verb
        {
        case .inherits(from: let id): 
            prose   = " inherits from "
            object  = id
        case .conforms(to: let id):
            prose   = " conforms to "
            object  = id
        case .is(let id):
            prose   = " is "
            object  = id
        }
        return 
            [
                Frontend[.code]
                {
                    Self.render(lexeme: subject) { self.symbols[$0] }
                },
                Frontend.text(escaped: prose), 
                Frontend[.code]
                {
                    Self.render(lexeme: .code(constraint.object, class: .type(object))) { self.symbols[$0] }
                },
            ]
    }
    func render(constraints:[Language.Constraint]) -> [Frontend] 
    {
        guard let ultimate:Language.Constraint = constraints.last 
        else 
        {
            fatalError("cannot call \(#function) with empty constraints array")
        }
        guard let penultimate:Language.Constraint = constraints.dropLast().last
        else 
        {
            return self.render(constraint: ultimate)
        }
        if constraints.count < 3 
        {
            return self.render(constraint: penultimate) + 
                CollectionOfOne<Frontend>.init(.text(escaped: " and ")) + 
                self.render(constraint: ultimate)
        }
        else 
        {
            var fragments:[Frontend] = .init(constraints.dropLast()
                .map(self.render(constraint:))
                .joined(separator: CollectionOfOne<Frontend>.init(.text(escaped: ", "))))
            fragments.append(.text(escaped: ", and "))
            fragments.append(contentsOf: self.render(constraint: ultimate))
            return fragments
        }
    }
    static 
    func render(lexeme:Language.Lexeme, resolve:((Symbol.ID) -> Symbol?)? = nil) -> Frontend
    {
        switch lexeme
        {
        case .code(let text, class: let classification):
            let css:String
            switch classification 
            {
            case .punctuation: 
                return Frontend.text(escaping: text)
            case .type(let id?):
                guard let resolve:(Symbol.ID) -> Symbol? = resolve 
                else 
                {
                    fallthrough
                }
                guard let resolved:Symbol = resolve(id)
                else 
                {
                    print("warning: no symbol for id '\(id)'")
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
            case .directive, .attribute, .keyword(.other):
                css = "syntax-keyword"
            case .keyword(.`init`):
                css = "syntax-keyword syntax-swift-init"
            case .keyword(.deinit):
                css = "syntax-keyword syntax-swift-deinit"
            case .keyword(.subscript):
                css = "syntax-keyword syntax-swift-subscript"
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
    static 
    func render(code:[Language.Lexeme], resolve:((Symbol.ID) -> Symbol?)? = nil) -> [Frontend] 
    {
        code.map { Self.render(lexeme: $0, resolve: resolve) }
    }
    func render(code:[Language.Lexeme]) -> [Frontend] 
    {
        Self.render(code: code) { self.symbols[$0] }
    }
    func renderArticle(_ symbol:Symbol) -> Frontend
    {
        let relationships:[Frontend] = (symbol.interface.map 
        {
            _ in 
            [
                Frontend[.p]
                {
                    ["required"]
                }
                content:
                {
                    "Required."
                }
            ]
        } ?? [])
        + 
        symbol.upstream.compactMap
        {
            (conformance:(index:Index, conditions:[Language.Constraint])) in 
            
            guard !conformance.conditions.isEmpty 
            else 
            {
                return nil 
            }
            return Frontend[.p]
            {
                "Conforms to "
                Frontend[.code] 
                {
                    Frontend[.a]
                    {
                        (self[conformance.index].path.canonical, as: Document.HTML.Href.self)
                    }
                    content: 
                    {
                        Self.render(code: self[conformance.index].breadcrumbs.lexemes)
                    }
                }
                " when "
                self.render(constraints: conformance.conditions)
            }
        }
        
        return Frontend[.article]
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
                if let head:Frontend = symbol.discussion.head 
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
                if !relationships.isEmpty 
                {
                    Frontend[.ul]
                    {
                        ["relationships-list"]
                    }
                    content: 
                    {
                        for item:Frontend in relationships
                        {
                            Frontend[.li]
                            {
                                item
                            }
                        }
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
                        self.render(code: symbol.declaration)
                    }
                }
            }
            Frontend[.section]
            {
                ["discussion"]
            }
            content: 
            {
                symbol.discussion.body
            }
        }
    }
    func renderSection(_ types:[(index:Index, conditions:[Language.Constraint])], heading:String) 
        -> Frontend?
    {
        if types.isEmpty
        {
            return nil 
        }
        return Frontend[.section]
        {
            ["relationships"]
        }
        content: 
        {
            Frontend[.h2]
            {
                heading
            }
            Frontend[.ul]
            {
                for (index, conditions):(Index, [Language.Constraint]) in types 
                {
                    Frontend[.li]
                    {
                        Frontend[.code]
                        {
                            ["signature"]
                        }
                        content: 
                        {
                            Frontend[.a]
                            {
                                (self[index].path.canonical, as: Document.HTML.Href.self)
                            }
                            content: 
                            {
                                Self.render(code: self[index].breadcrumbs.lexemes)
                            }
                        }
                        if !conditions.isEmpty
                        {
                            Frontend[.p]
                            {
                                ["relationship"]
                            }
                            content: 
                            {
                                "When "
                                self.render(constraints: conditions)
                            }
                        }
                    }
                }
            }
        }
    }
    func renderTopics<S>(_ topics:S, heading:String) -> Frontend?
        where S:Sequence, S.Element == (key:Entrapta.Topic, indices:[Index])
    {
        let topics:[Frontend] = topics.map
        {
            (topic:(heading:Entrapta.Topic, members:[Index])) in 
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
                        topic.heading.description
                    }
                }
                Frontend[.ul]
                {
                    ["topic-container-right"]
                }
                content:
                {
                    for index:Index in topic.members
                    {
                        let member:Symbol = self[index]
                        Frontend[.li]
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
                            if let head:Frontend = member.discussion.head 
                            {
                                head
                            }
                            
                            if let overridden:Index = member.overrides 
                            {
                                if let abstract:Index = self[overridden].parent 
                                {
                                    switch self[abstract].kind 
                                    {
                                    case .declaration(.class):
                                        self.renderRelationship(overridden, "Overrides virtual member in ", abstract)
                                    case .declaration(.protocol):
                                        self.renderRelationship(overridden, "Type inference hint for requirement in ", abstract)
                                    default: 
                                        let _:Void = print("warning: parent of overridden symbol '\(self[overridden].title)' is not a class or protocol")
                                    }
                                }
                                else 
                                {
                                    let _:Void = print("warning: parent of overridden symbol '\(self[overridden].title)' does not exist")
                                }
                            } 
                        }
                    } 
                }
            }
        }
        guard !topics.isEmpty 
        else 
        {
            return nil
        }
        return Frontend[.section]
        {
            ["topics"]
        }
        content: 
        {
            Frontend[.h2]
            {
                heading
            }
            topics
        }
    }
    func renderRelationship(_ target:Index, _ prose:String, _ type:Index) -> Frontend
    {
        Frontend[.p]
        {
            ["relationship"]
        }
        content:
        {
            prose 
            Frontend[.code]
            {
                Frontend[.a]
                {
                    (self[target].path.canonical, as: Document.HTML.Href.self)
                }
                content: 
                {
                    Self.render(code: self[type].breadcrumbs.lexemes)
                }
            }
        }
    }
    func renderEpilogue(_ symbol:Symbol) -> Frontend?
    {
        var category:String 
        if case .declaration(.protocol) = symbol.kind 
        {
            category = "Implies"
        }
        else 
        {
            category = "Conforms To"
        }
        // TODO: use the constraint information
        return self.renderSection(symbol.upstream, heading: category)
    }
    func renderMain(_ symbol:Symbol) -> Frontend
    {
        return Frontend[.main, id: nil]
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
                    self.renderArticle(symbol)
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
                    self.renderSection(symbol.downstream.map { ($0, []) }, heading: "Refinements")
                    
                    self.renderTopics(symbol.topics.requirements, heading: "Requirements")
                    self.renderTopics(symbol.topics.members, heading: "Members")
                    
                    self.renderSection(symbol.subclasses.map { ($0, []) }, heading: "Subclasses")
                    self.renderSection(symbol.conformers, heading: "Conforming Types")
                    self.renderEpilogue(symbol)
                }
            }
        }
    }
    func renderNavigation(_ symbol:Symbol) -> Frontend
    {
        let tail:Frontend           = Frontend[.li]
        {
            symbol.breadcrumbs.tail 
        }
        var breadcrumbs:[Frontend]  = [tail]
        var next:Index?             = symbol.parent
        while let index:Index       = next 
        {
            let parent:Symbol       = self[index]
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
    func render(_ symbol:Symbol) -> Page
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
                self.renderNavigation(symbol)
                self.renderMain(symbol)
            }
        }
    }
}
extension Entrapta
{
    public 
    enum Response 
    {
        case canonical(Graph.Page)
        case found(String)
    }
    public 
    struct Documentation:Sendable
    {
        typealias Index = Dictionary<Graph.Symbol.Path, Graph.Page>.Index 
        
        var pages:[Graph.Symbol.Path: Graph.Page]
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
            var graph:Graph     = try .init(prefix: prefix, modules: json)
            // rendering must take place in two passes, since pages can include 
            // snippets of other pages 
            for index:Graph.Index in graph.symbols.indices 
            {
                guard !graph[index].comment.isEmpty
                else 
                {
                    continue 
                }
                graph[index].discussion     = Entrapta.render(markdown: graph[index].comment)
                {
                    (path:String?) in 
                    Graph.Frontend[.code]
                    {
                        path ?? "<unknown>"
                    }
                }
                link: 
                {
                    (target:String?, content:[Graph.Frontend]) in 
                    if let target:String = target
                    {
                        return Graph.Frontend[.a]
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
                        return Graph.Frontend[.span]
                        {
                            content
                        }
                    }
                }
                image: 
                {
                    (source:String?, alt:[Graph.Frontend], title:String?) in 
                    if let source:String = source
                    {
                        return Graph.Frontend[.img]
                        {
                            (source, as: Document.HTML.Src.self)
                        }
                    }
                    else 
                    {
                        return Graph.Frontend[.img]
                    }
                }
                highlight: 
                {
                    (code:String) in 
                    Graph.Frontend[.pre]
                    {
                        ["notebook"]
                    }
                    content:
                    {
                        Graph.Frontend[.code]
                        {
                            graph.render(code: Language.highlight(code: code))
                        }
                    }
                }
            }
            self.init(graph: graph, prefix: prefix)
        }
        
        init(graph:Graph, prefix:[String]) 
        {
            // paths are always unique at this point 
            let pages:[Graph.Symbol.Path: Graph.Page] = .init(uniqueKeysWithValues: 
                graph.symbols.values.map { ($0.path, graph.render($0)) })
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
        
        /// the `group` is the full URL path, without the query, and including 
        /// the beginning slash '/' and path prefix. 
        /// the path *must* be normalized with respect to slashes, but it 
        /// *must not* be percent-decoded. (otherwise the user may be sent into 
        /// an infinite redirect loop.)
        ///
        /// '/reference/swift-package/somemodule/foo/bar.baz%28_%3A%29':    OK (canonical page for `SomeModule.Foo.Bar.baz(_:)`)
        /// '/reference/swift-package/somemodule/foo/bar.baz(_:)':          OK (301 redirect to `SomeModule.Foo.Bar.baz(_:)`)
        /// '/reference/swift-package/SomeModule/FOO/BAR.BAZ(_:)':          OK (301 redirect to `SomeModule.Foo.Bar.baz(_:)`)
        /// '/reference/swift-package/somemodule/foo/bar%2Ebaz%28_%3A%29':  OK (301 redirect to `SomeModule.Foo.Bar.baz(_:)`)
        /// '/reference/swift-package/somemodule/foo//bar.baz%28_%3A%29':   Error (slashes not normalized)
        ///
        /// note: the URL of a page for an operator containing a slash '/' *must*
        /// be percent-encoded; Entrapta will not be able to redirect it to the 
        /// correct canonical URL. 
        ///
        /// note: the URL path is case-insensitive, but the disambiguation query 
        /// *is* case-sensitive. the `disambiguation` parameter should include 
        /// the mangled name only, without the `?overload=` part. if you provide 
        /// a valid disambiguation query, the URL path can be complete garbage; 
        /// Entrapta will respond with a 301 redirect to the correct page.
        public 
        subscript(group:String, disambiguation disambiguation:String?) -> Response?
        {
            let path:Graph.Symbol.Path  = .init(group: Entrapta.normalize(path: group), 
                disambiguation: disambiguation.map(Graph.Symbol.ID.declaration(precise:)))
            if let page:Graph.Page = self.pages[path]
            {
                return path.group == group ? .canonical(page) : .found(path.canonical)
            }
            guard let key:Graph.Symbol.ID = path.disambiguation
            else 
            {
                return nil 
            }
            //  we were given a bad path + disambiguation key combo, 
            //  but the query might still be valid 
            if let index:Index = self.disambiguations[key]
            {
                return .found(self.pages.keys[index].canonical)
            }
            //  we were given an extraneous disambiguation key, but the path might 
            //  still be valid
            let truncated:Graph.Symbol.Path = .init(group: path.group)
            if case _? = self.pages[truncated]
            {
                return .found(truncated.canonical)
            }
            else 
            {
                return nil
            }
        }
    }
}
