import Resource
import StructuredDocument 
import HTML 
import JSON

extension Biome.Symbol 
{
    public 
    enum Anchor:String, DocumentID, Sendable
    {
        case search         = "search"
        case searchInput    = "search-input"
        case searchResults  = "search-results"
        
        public 
        var documentId:String 
        {
            self.rawValue
        }
    }
}
extension Biome 
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
    static 
    func render(availability:Symbol.Availability) -> [Frontend]
    {
        var clauses:[Frontend] = []
        if let version:Version = availability.introduced
        {
            clauses.append(Frontend[.p]
            {
                Frontend.span("\(version.description)+")
                {
                    ["version", "introduced"]
                }
            })
        }
        if availability.unavailable 
        {
            // unconditionally unavailable 
            clauses.append(Frontend[.p]
            {
                Frontend[.strong]
                {
                    "Unavailable"
                }
            })
        }
        if let deprecation:Version? = availability.deprecated 
        {
            clauses.append(Frontend[.p]
            {
                Frontend[.strong]
                {
                    "Deprecated"
                }
                if let version:Version = deprecation 
                {
                    " since "
                    Frontend.span(version.description)
                    {
                        ["version"]
                    }
                }
            })
        }
        if let version:Version = availability.obsoleted 
        {
            clauses.append(Frontend[.p]
            {
                Frontend[.strong]
                {
                    "Obsolete"
                }
                " since "
                Frontend.span(version.description)
                {
                    ["version"]
                }
            })
        }
        // need to render markdown
        /* if let message:String = availability.message 
        {
            clauses.append(Frontend[.p]
            {
                ["message"]
            }
            content:
            {
                message
            })
        } */
        return clauses
    }
    func renderArticle(_ symbol:Symbol) -> Frontend
    {
        let module:(index:Index, extended:(index:Index, where:[Language.Constraint])?)?
        if case .module = symbol.kind 
        {
            module = nil 
        }
        else if let defined:Index = self.symbols.index(forKey: .module(symbol.module))
        {
            if let (name, constraints):(String, [Language.Constraint]) = symbol.extends 
            {
                if let extended:Index = self.modules[name]
                {
                    module = (defined, (extended, constraints))
                }
                else 
                {
                    print("warning: could not find extended module '\(name)'")
                    module = (defined, nil)
                }
            }
            else 
            {
                module = (defined, nil)
            }
        }
        else 
        {
            print("warning: could not find module '\(symbol.module)'")
            module = nil 
        }
        
        let platforms:[Frontend] = 
        [
            Symbol.Domain.iOS,
            Symbol.Domain.macOS,
            Symbol.Domain.macCatalyst,
            Symbol.Domain.tvOS,
            Symbol.Domain.watchOS,
            Symbol.Domain.windows,
            Symbol.Domain.openBSD,
        ].compactMap
        {
            (platform:Symbol.Domain) in 
            guard let version:Version = symbol.availability[platform]?.introduced 
            else 
            {
                return nil 
            }
            return Frontend[.li]
            {
                "\(platform.rawValue) "
                Frontend.span("\(version.description)+")
                {
                    ["version"]
                }
            }
        }
        var relationships:[Frontend] = symbol.interface.map 
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
        } ?? []
        if let constraints:[Language.Constraint] = module?.extended?.where, !constraints.isEmpty
        {
            relationships.append(Frontend[.p]
            {
                "Available when "
                self.render(constraints: constraints)
            })
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
                Frontend[.div]
                {
                    ["eyebrows"]
                }
                content:
                {
                    Frontend.span(symbol.kind.title)
                    {
                        ["kind"]
                    }
                    if let module:(index:Index, extended:(index:Index, where:[Language.Constraint])?) = module 
                    {
                        Frontend[.span]
                        {
                            ["module"]
                        }
                        content: 
                        {
                            if let extended:Index = module.extended?.index 
                            {
                                Frontend[.span]
                                {
                                    ["extended"]
                                }
                                content:
                                {
                                    Frontend.link(self[extended].module.title, to: self[extended].path.canonical, internal: true)
                                }
                            }
                            Frontend.link(self[module.index].module.title, to: self[module.index].path.canonical, internal: true)
                        }
                    }
                    else 
                    {
                        Frontend[.code]
                        {
                            ["package"]
                        }
                        content: 
                        {
                            switch symbol.module 
                            {
                            case .swift, .concurrency: 
                                "swift"
                            case .community(module: _, package: let package): 
                                package
                            }
                        }
                    }
                }
                Frontend[.h1]
                {
                    symbol.title
                }
                if let head:Frontend = symbol.comment.processed.head 
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
                if let availability:Symbol.Availability = symbol.availability[.swift]
                {
                    Frontend[.section]
                    {
                        ["availability"]
                    }
                    content:
                    {
                        Self.render(availability: availability)
                    }
                }
                if let availability:Symbol.Availability = symbol.availability[.wildcard]
                {
                    Frontend[.section]
                    {
                        ["availability"]
                    }
                    content:
                    {
                        Self.render(availability: availability)
                    }
                }
            }
            if !platforms.isEmpty 
            {
                Frontend[.section]
                {
                    ["platforms"]
                }
                content: 
                {
                    Frontend[.ul]
                    {
                        platforms
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
            if !symbol.comment.processed.parameters.isEmpty
            {
                Frontend[.section]
                {
                    ["parameters"]
                }
                content: 
                {
                    Frontend[.h2]
                    {
                        "Parameters"
                    }
                    Frontend[.dl]
                    {
                        for (name, comment):(String, [Frontend]) in symbol.comment.processed.parameters 
                        {
                            Frontend[.dt]
                            {
                                name
                            }
                            Frontend[.dd]
                            {
                                comment
                            }
                        }
                    }
                }
            }
            if !symbol.comment.processed.returns.isEmpty
            {
                Frontend[.section]
                {
                    ["returns"]
                }
                content: 
                {
                    Frontend[.h2]
                    {
                        "Returns"
                    }
                    symbol.comment.processed.returns
                }
            }
            if !symbol.comment.processed.body.isEmpty 
            {
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
                    symbol.comment.processed.body
                }
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
        where S:Sequence, S.Element == (heading:Topic, indices:[Index])
    {
        let topics:[Frontend] = topics.map
        {
            (topic:(heading:Topic, indices:[Index])) in 
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
                    for index:Index in topic.indices
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
                            if let head:Frontend = member.comment.processed.head 
                            {
                                head
                            }
                            
                            if let overridden:Index = member.overrides 
                            {
                                if let abstract:Index = self[overridden].parent 
                                {
                                    switch self[abstract].kind 
                                    {
                                    case .class:
                                        self.renderRelationship(overridden, "Overrides virtual member in ", abstract)
                                    case .protocol:
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
        if case .protocol = symbol.kind 
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
        var breadcrumbs:[Frontend]
        if let tail:String  = symbol.breadcrumbs.body.last 
        {
            breadcrumbs     = [ Frontend[.li] { tail } ]
            var next:Index?             = symbol.parent
            while   let index:Index     = next, 
                    let tail:String     = self[index].breadcrumbs.body.last 
            {
                breadcrumbs.append(Frontend[.li]
                {
                    Frontend.link(tail, to: self[index].path.canonical, internal: true)
                })
                next = self[index].parent
            }
        }
        else 
        {
            breadcrumbs = [ Frontend[.li] { symbol.breadcrumbs.head.title } ]
        }
        
        return Frontend[.nav, id: nil]
        {
            Frontend[.div]
            {
                ["breadcrumbs"]
            } 
            content: 
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
            Frontend[.div]
            {
                ["search-bar"]
            } 
            content: 
            {
                Frontend[.form, id: .search] 
                {
                    Document.HTML.Role.search
                }
                content: 
                {
                    Frontend[.div]
                    {
                        ["input-container"]
                    }
                    content: 
                    {
                        Frontend[.div]
                        {
                            ["bevel"]
                        }
                        Frontend[.div]
                        {
                            ["rectangle"]
                        }
                        content: 
                        {
                            Frontend[.input, id: .searchInput]
                            {
                                Document.HTML.InputType.search
                                Document.HTML.Autocomplete.off
                                // (true, as: Document.HTML.Autofocus.self)
                                ("search symbols", as: Document.HTML.Placeholder.self)
                            }
                        }
                        Frontend[.div]
                        {
                            ["bevel"]
                        }
                    }
                    Frontend[.ol, id: .searchResults]
                }
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
                    symbol.title
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
                Frontend[.script]
                {
                    ("/lunr.js", as: Document.HTML.Src.self)
                    (true, as: Document.HTML.Defer.self)
                }
                Frontend[.script]
                {
                    ("/search.js", as: Document.HTML.Src.self)
                    (true, as: Document.HTML.Defer.self)
                }
                Frontend[.link]
                {
                    ("/biome.css", as: Document.HTML.Href.self)
                    Document.HTML.Rel.stylesheet
                }
                Frontend[.link]
                {
                    ("/favicon.png", as: Document.HTML.Href.self)
                    Document.HTML.Rel.icon
                }
                Frontend[.link]
                {
                    ("/favicon.ico", as: Document.HTML.Href.self)
                    Document.HTML.Rel.icon
                    Resource.Binary.icon
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
extension Biome 
{
    func renderSymbolLink(to path:String?) -> Frontend
    {
        Frontend[.code]
        {
            path ?? "<unknown>"
        }
    }
    func renderLink(to target:String?, _ content:[Frontend]) -> Frontend
    {
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
    func renderImage(source:String?, alt:[Frontend], title:String?) -> Frontend
    {
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
    func renderNotebook(highlighting code:String) -> Frontend
    {
        Frontend[.pre]
        {
            ["notebook"]
        }
        content:
        {
            Frontend[.code]
            {
                Self.render(lexeme: .newlines(0))
                self.render(code: Language.highlight(code: code))
            }
        }
    }
}
extension Biome
{
    public 
    enum Response 
    {
        case canonical(Page)
        case found(String)
    }
    public 
    struct Diagnostics 
    {
        var uri:String
        
        mutating 
        func warning(_ string:String)
        {
            print("(\(self.uri)): \(string)")
        }
    }
    public 
    struct Documentation:Sendable
    {
        typealias Index = Dictionary<Symbol.Path, Page>.Index 
        
        let pages:[Symbol.Path: Page]
        let disambiguations:[Symbol.ID: Index]
        
        public 
        let search:JSON
        
        public 
        init(_ namespaces:[Namespace: [UInt8]], prefix:[String]) throws 
        {
            let prefix:[String] = prefix.map{ $0.lowercased() }
            let json:[Namespace: JSON] = try namespaces.mapValues 
            {
                try Grammar.parse($0, as: JSON.Rule<Array<UInt8>.Index>.Root.self)
            }
            print("parsed JSON")
            var biome:Biome = try .init(namespaces: json, prefix: prefix)
            var diagnostics:Diagnostics = .init(uri: "/")
            // rendering must take place in two passes, since pages can include 
            // snippets of other pages 
            for index:Biome.Index in biome.symbols.indices 
            {
                guard !biome[index].comment.text.isEmpty
                else 
                {
                    continue 
                }
                diagnostics.uri = biome[index].path.canonical 
                biome[index].comment.processed = biome.render(
                    markdown: biome[index].comment.text, 
                    parameters: biome[index].parameters, 
                    diagnostics: &diagnostics)
            }
            self.init(biome: biome)
        }
        
        init(biome:Biome) 
        {
            // paths are always unique at this point 
            let pages:[Symbol.Path: Page] = .init(uniqueKeysWithValues: 
                biome.symbols.values.map { ($0.path, biome.render($0)) })
            self.disambiguations = .init(uniqueKeysWithValues: biome.symbols.map 
            {
                guard let index:Index = pages.index(forKey: $0.value.path)
                else 
                {
                    fatalError("unreachable")
                }
                return ($0.key, index)
            })
            self.pages  = _move(pages)
            self.search = .array(biome.search.map 
            { 
                .object(["uri": .string($0.uri), "title": .string($0.title), "text": .array($0.text.map(JSON.string(_:)))]) 
            })
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
        /// be percent-encoded; Biome will not be able to redirect it to the 
        /// correct canonical URL. 
        ///
        /// note: the URL path is case-insensitive, but the disambiguation query 
        /// *is* case-sensitive. the `disambiguation` parameter should include 
        /// the mangled name only, without the `?overload=` part. if you provide 
        /// a valid disambiguation query, the URL path can be complete garbage; 
        /// Biome will respond with a 301 redirect to the correct page.
        public 
        subscript(group:String, disambiguation disambiguation:String?) -> Response?
        {
            let path:Symbol.Path  = .init(group: Biome.normalize(path: group), 
                disambiguation: disambiguation.map(Symbol.ID.declaration(precise:)))
            if let page:Page = self.pages[path]
            {
                return path.group == group ? .canonical(page) : .found(path.canonical)
            }
            guard let key:Symbol.ID = path.disambiguation
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
            let truncated:Symbol.Path = .init(group: path.group)
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
