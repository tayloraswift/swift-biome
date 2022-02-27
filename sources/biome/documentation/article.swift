import Markdown
import Resource
import StructuredDocument
import HTML

extension Biome 
{
    public 
    typealias Frontend  = StructuredDocument.Document.Element<HTML, Anchor>
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
    
    func page(for module:Int, article:Article, articles:[Article]) -> Resource
    {
        let dynamic:Frontend = Frontend[.div]
        {
            ["lower-container"]
        }
        content:
        {
            self.render(topics: self.modules[module].topics.members, heading: "Members", articles: articles)
            self.render(topics: self.modules[module].topics.removed, heading: "Removed Members", articles: articles)
        }
        return self.page(title: self.modules[module].title, article: article, dynamic: dynamic)
    }
    func page(for index:Int, articles:[Article]) -> Resource
    {
        let symbol:Symbol       = self.symbols[index]
        let dynamic:Frontend    = Frontend[.div]
        {
            ["lower-container"]
        }
        content:
        {
            if case .protocol(let abstract) = symbol.relationships 
            {
                self.render(list: abstract.downstream.map { ($0, []) }, heading: "Refinements")
            }
            
            self.render(topics: symbol.topics.requirements, heading: "Requirements", articles: articles)
            self.render(topics: symbol.topics.members,      heading: "Members", articles: articles)
            
            switch symbol.relationships 
            {
            case .protocol(let abstract):
                self.render(list: abstract.upstream.map{ ($0, []) },    heading: "Implies")
                self.render(list: abstract.conformers,                  heading: "Conforming Types")
            case .class(let concrete, subclasses: let subclasses, superclass: _):
                self.render(list: subclasses.map { ($0, []) },          heading: "Subclasses")
                self.render(list: concrete.upstream,                    heading: "Conforms To")
            case .enum(let concrete), .struct(let concrete), .actor(let concrete):
                self.render(list: concrete.upstream,                    heading: "Conforms To")
            default: 
                let _:Void = ()
            }
            
            self.render(topics: symbol.topics.removed,      heading: "Removed Members", articles: articles)
        }
        return self.page(title: symbol.title, article: articles[index], dynamic: dynamic)
    }
    func page(title:String, article:Article, dynamic:Frontend) -> Resource
    {
        let document:StructuredDocument.Document.Dynamic<HTML, Anchor> = .init 
        {
            HTML.Lang.en
        }
        content:
        {
            Frontend[.head]
            {
                Frontend[.title] 
                {
                    title
                }
                Frontend.metadata(charset: Unicode.UTF8.self)
                Frontend.metadata 
                {
                    ("viewport", "width=device-width, initial-scale=1")
                }
                
                Frontend[.link] 
                {
                    ("https://fonts.googleapis.com", as: HTML.Href.self)
                    HTML.Rel.preconnect 
                }
                Frontend[.link] 
                {
                    HTML.Crossorigin.anonymous 
                    ("https://fonts.gstatic.com", as: HTML.Href.self)
                    HTML.Rel.preconnect 
                }
                Frontend[.link] 
                {
                    ("https://fonts.googleapis.com/css2?family=Literata:ital,wght@0,400;0,600;1,400;1,600&display=swap", as: HTML.Href.self)
                    HTML.Rel.stylesheet 
                }
                Frontend[.script]
                {
                    ("/lunr.js", as: HTML.Src.self)
                    (true, as: HTML.Defer.self)
                }
                Frontend[.script]
                {
                    ("/search.js", as: HTML.Src.self)
                    (true, as: HTML.Defer.self)
                }
                Frontend[.link]
                {
                    ("/biome.css", as: HTML.Href.self)
                    HTML.Rel.stylesheet
                }
                Frontend[.link]
                {
                    ("/favicon.png", as: HTML.Href.self)
                    HTML.Rel.icon
                }
                Frontend[.link]
                {
                    ("/favicon.ico", as: HTML.Href.self)
                    HTML.Rel.icon
                    Resource.Binary.icon
                }
            }
            Frontend[.body]
            {
                ["documentation"]
            }
            content: 
            {
                Frontend[.nav]
                {
                    Frontend[.div]
                    {
                        ["breadcrumbs"]
                    } 
                    content: 
                    {
                        article.navigator
                    }
                    Frontend[.div]
                    {
                        ["search-bar"]
                    } 
                    content: 
                    {
                        Frontend[.form, id: .search] 
                        {
                            HTML.Role.search
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
                                        HTML.InputType.search
                                        HTML.Autocomplete.off
                                        // (true, as: HTML.Autofocus.self)
                                        ("search symbols", as: HTML.Placeholder.self)
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
                Frontend[.main]
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
                            article.full
                        }
                    }
                    Frontend[.div]
                    {
                        ["lower"]
                    }
                    content: 
                    {
                        dynamic
                    }
                }
            }
        }
        return .html(document, version: nil)
    }
    
    private 
    func render<S>(list types:S, heading:String) -> Frontend?
        where S:Sequence, S.Element == (index:Int, conditions:[Language.Constraint])
    {
        // we will discard all errors from dynamic rendering
        var renderer:DiagnosticRenderer = .init(biome: self, errors: [])
        let list:[Frontend] = types.map 
        {
            (item:(index:Int, conditions:[Language.Constraint])) in 
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
                        (self.symbols[item.index].path.canonical, as: HTML.Href.self)
                    }
                    content: 
                    {
                        Self.render(code: self.symbols[item.index].qualified)
                    }
                }
                if !item.conditions.isEmpty
                {
                    Frontend[.p]
                    {
                        ["relationship"]
                    }
                    content: 
                    {
                        "When "
                        renderer.render(constraints: item.conditions)
                    }
                }
            }
        }
        guard !list.isEmpty
        else
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
                list
            }
        }
    }
    private 
    func render<S>(topics:S, heading:String, articles:[Article]) -> Frontend?
        where S:Sequence, S.Element == (heading:Topic, indices:[Int])
    {
        let topics:[Frontend] = topics.map
        {
            (topic:(heading:Topic, indices:[Int])) in 
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
                    for index:Int in topic.indices
                    {
                        articles[index].card
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
    
    typealias Comment =
    (
        head:Frontend?, 
        parameters:[(name:String, comment:[Frontend])],
        returns:[Frontend],
        discussion:[Frontend]
    )
    
    struct Article 
    {
        var navigator:Frontend
        {
            .text(escaped: self.baked.navigator)
        }
        var card:Frontend
        {
            .text(escaped: self.baked.card)
        }
        var full:Frontend
        {
            .text(escaped: self.baked.full)
        }
        
        let errors:[Error]
        
        private 
        let baked:
        (
            navigator:String,
            card:String,
            full:String
        )
        
        var size:Int 
        {
            self.baked.navigator.utf8.count +
            self.baked.card.utf8.count + 
            self.baked.full.utf8.count
        }
        
        init(navigator:String, card:String, full:String, errors:[Error])
        {
            self.baked = (navigator: navigator, card: card, full: full)
            self.errors = errors 
        }
    }
    
    func article(module index:Int, comment:String) -> Article
    {
        let card:Frontend       = Frontend[.li] 
        { 
            self.modules[index].title 
        }
        let navigator:Frontend  = Frontend[.ol] 
        {
            ["breadcrumbs-container"]
        }
        content:
        {
            card
        }
        var renderer:DiagnosticRenderer = .init(biome: self, errors: [])
        let comment:Comment = renderer.content(markdown: comment)
        let full:Frontend = Frontend[.article]
        {
            ["upper-container-left"]
        }
        content: 
        {
            renderer.introduction(for: self.modules[index], blurb: comment.head)
            renderer.render(declaration: self.modules[index].declaration)
            // these shouldn’t usually be here, but if for some reason, someone 
            // writes a module doc that has these fields, print them instead of 
            // discarding them.
            Self.render(parameters: comment.parameters)
            Self.render(section: comment.returns,       heading: "Returns",  class: "returns")
            Self.render(section: comment.discussion,    heading: "Overview", class: "discussion")
        }
        return .init(
            navigator:  navigator.rendered, 
            card:       card.rendered, 
            full:       full.rendered, 
            errors:     renderer.errors)
    }
    func article(symbol index:Int, comment:String) -> Article
    {
        let symbol:Symbol           = self.symbols[index]
        
        var breadcrumbs:[Frontend]  = [ Frontend[.li] { symbol.breadcrumbs.last } ]
        var next:Int?               = symbol.breadcrumbs.parent
        while let index:Int         = next
        {
            breadcrumbs.append(Frontend[.li]
            {
                Frontend.link(self.symbols[index].breadcrumbs.last, to: self.symbols[index].path.canonical, internal: true)
            })
            next = self.symbols[index].breadcrumbs.parent
        }
        breadcrumbs.reverse()
        
        let navigator:Frontend  = Frontend[.ol] 
        {
            ["breadcrumbs-container"]
        }
        content:
        {
            breadcrumbs
        }
        
        var renderer:DiagnosticRenderer = .init(biome: self, errors: [])
        let comment:Comment = renderer.content(markdown: comment)
        
        let card:Frontend   = self.renderArticleCard(symbol, blurb: comment.head)
        let full:Frontend   = Frontend[.article]
        {
            ["upper-container-left"]
        }
        content: 
        {
            renderer.introduction(for: symbol, blurb: comment.head)
            Self.render(platforms: symbol.platforms)
            renderer.render(declaration: symbol.declaration)
            Self.render(parameters: comment.parameters)
            Self.render(section: comment.returns,       heading: "Returns",  class: "returns")
            Self.render(section: comment.discussion,    heading: "Overview", class: "discussion")
        }
        return .init(
            navigator:  navigator.rendered, 
            card:       card.rendered, 
            full:       full.rendered, 
            errors:     renderer.errors)
    }
    
    private 
    func renderArticleCard(_ symbol:Symbol, blurb:Frontend?) -> Frontend
    {
        var relationships:[Frontend]    = []
        if let overridden:Int           = symbol.relationships.overrideOf
        {
            guard let interface:Int     = self.symbols[overridden].breadcrumbs.parent 
            else 
            {
                fatalError("unimplemented: parent of overridden symbol '\(self.symbols[overridden].title)' does not exist")
            }
            let prose:String
            if case .protocol = self.symbols[interface].kind
            {
                prose = "Type inference hint for requirement in "
            } 
            else 
            {
                prose = "Overrides virtual member in "
            }
            relationships.append(Frontend[.li]
            {
                Frontend[.p]
                {
                    prose 
                    Frontend[.code]
                    {
                        Frontend[.a]
                        {
                            (self.symbols[overridden].path.canonical, as: HTML.Href.self)
                        }
                        content: 
                        {
                            Self.render(code: self.symbols[interface].qualified)
                        }
                    }
                }
            })
        } 
        /* if !symbol.extensionConstraints.isEmpty
        {
            relationships.append(Frontend[.li] 
            {
                Frontend[.p]
                {
                    "Available when "
                    self.render(constraints: symbol.extensionConstraints)
                }
            })
        } */
        
        let availability:[Frontend] = Self.render(availability: symbol.availability)
        return Frontend[.li]
        {
            Frontend[.code]
            {
                ["signature"]
            }
            content: 
            {
                Frontend[.a]
                {
                    (symbol.path.canonical, as: HTML.Href.self)
                }
                content: 
                {
                    Self.render(code: symbol.signature)
                }
            }
            if let blurb:Frontend = blurb 
            {
                blurb
            }
            if !relationships.isEmpty 
            {
                Frontend[.ul]
                {
                    ["relationships-list"]
                }
                content: 
                {
                    relationships
                }
            }
            if !availability.isEmpty 
            {
                Frontend[.ul]
                {
                    ["availability-list"]
                }
                content: 
                {
                    availability
                }
            }
        }
    }
    private 
    func renderArticleEyebrows(_ symbol:Symbol) -> Frontend 
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
            Frontend[.span]
            {
                ["module"]
            }
            content: 
            {
                if let extended:Int = symbol.bystander
                {
                    Frontend[.span]
                    {
                        ["extended"]
                    }
                    content:
                    {
                        Frontend.link(self.modules[extended].title, to: self.modules[extended].path.canonical, internal: true)
                    }
                }
                Frontend.link(self.modules[symbol.module].title, to: self.modules[symbol.module].path.canonical, internal: true)
            }
        }
    }

    private static 
    func render(availability:(unconditional:Symbol.UnconditionalAvailability?, swift:Symbol.SwiftAvailability?)) -> [Frontend]
    {
        var availabilities:[Frontend] = []
        if let availability:Symbol.UnconditionalAvailability = availability.unconditional
        {
            if availability.unavailable 
            {
                availabilities.append(Self.render(availability: "Unavailable"))
            }
            else if availability.deprecated 
            {
                availabilities.append(Self.render(availability: "Deprecated"))
            }
        }
        if let availability:Symbol.SwiftAvailability = availability.swift
        {
            if let version:Version = availability.obsoleted 
            {
                availabilities.append(Self.render(availability: "Obsolete", since: ("Swift", version)))
            } 
            else if let version:Version = availability.deprecated 
            {
                availabilities.append(Self.render(availability: "Deprecated", since: ("Swift", version)))
            }
            else if let version:Version = availability.introduced
            {
                availabilities.append(Self.render(availability: "Available", since: ("Swift", version)))
            }
        }
        return availabilities
    }
    private static 
    func render(availability adjective:String, since:(domain:String, version:Version)? = nil) -> Frontend
    {
        Frontend[.li]
        {
            Frontend[.p]
            {
                Frontend[.strong]
                {
                    adjective
                }
                if let (domain, version):(String, Version) = since 
                {
                    " since \(domain) "
                    Frontend.span(version.description)
                    {
                        ["version"]
                    }
                }
            }
        }
    }
    
    static 
    func render(code:[Language.Lexeme]) -> [Frontend] 
    {
        code.map(Self.render(lexeme:))
    }
    static 
    func render(lexeme:Language.Lexeme) -> Frontend
    {
        switch lexeme
        {
        case .code(let text, class: let classification):
            let css:String
            switch classification 
            {
            case .punctuation: 
                return Frontend.text(escaping: text)
            case .type:
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
    
    private static
    func render(platforms availability:[Symbol.Domain: Symbol.Availability]) 
        -> Frontend?
    {
        var platforms:[Frontend] = []
        for platform:Symbol.Domain in Symbol.Domain.platforms 
        {
            if let availability:Symbol.Availability = availability[platform]
            {
                if availability.unavailable 
                {
                    platforms.append(Frontend[.li]
                    {
                        "\(platform.rawValue) unavailable"
                    })
                }
                else if case nil? = availability.deprecated 
                {
                    platforms.append(Frontend[.li]
                    {
                        "\(platform.rawValue) deprecated"
                    })
                }
                else if case let version?? = availability.deprecated 
                {
                    platforms.append(Frontend[.li]
                    {
                        "\(platform.rawValue) deprecated since "
                        Frontend.span("\(version.description)")
                        {
                            ["version"]
                        }
                    })
                }
                else if let version:Version = availability.introduced 
                {
                    platforms.append(Frontend[.li]
                    {
                        "\(platform.rawValue) "
                        Frontend.span("\(version.description)+")
                        {
                            ["version"]
                        }
                    })
                }
            }
        }
        guard !platforms.isEmpty
        else 
        {
            return nil
        }
        return Frontend[.section]
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
    private static 
    func render(section content:[Frontend], heading:String, class:String) -> Frontend?
    {
        guard !content.isEmpty 
        else 
        {
            return nil 
        }
        return Frontend[.section]
        {
            [`class`]
        }
        content: 
        {
            Frontend[.h2]
            {
                heading
            }
            content
        }
    }
    private static 
    func render(parameters:[(name:String, comment:[Frontend])]) -> Frontend?
    {
        guard !parameters.isEmpty 
        else 
        {
            return nil 
        }
        return Frontend[.section]
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
                for (name, comment):(String, [Frontend]) in parameters 
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
    
    struct DiagnosticRenderer 
    {
        let biome:Biome 
        var errors:[Error]
        
        mutating 
        func render(code:[Language.Lexeme]) -> [Frontend] 
        {
            code.map 
            {
                self.render(lexeme: $0)
            }
        }
        mutating 
        func render(lexeme:Language.Lexeme) -> Frontend
        {
            guard case .code(let text, class: .type(let id?)) = lexeme
            else 
            {
                return Biome.render(lexeme: lexeme)
            }
            guard let path:Path = self.biome.symbols[id]?.path
            else 
            {
                self.errors.append(SymbolIdentifierError.undefined(symbol: id))
                return Biome.render(lexeme: lexeme)
            }
            return Frontend.link(text, to: path.canonical, internal: true)
            {
                ["syntax-type"] 
            }
        }
        mutating 
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
                        self.render(lexeme: subject)
                    },
                    Frontend.text(escaped: prose), 
                    Frontend[.code]
                    {
                        self.render(lexeme: .code(constraint.object, class: .type(object)))
                    },
                ]
        }
        mutating 
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
            var fragments:[Frontend]
            if constraints.count < 3 
            {
                fragments =                  self.render(constraint: penultimate)
                fragments.append(.text(escaped: " and "))
                fragments.append(contentsOf: self.render(constraint: ultimate))
            }
            else 
            {
                fragments = []
                for constraint:Language.Constraint in constraints.dropLast(2)
                {
                    fragments.append(contentsOf: self.render(constraint: constraint))
                    fragments.append(.text(escaped: ", "))
                }
                fragments.append(contentsOf: self.render(constraint: penultimate))
                fragments.append(.text(escaped: ", and "))
                fragments.append(contentsOf: self.render(constraint: ultimate))
            }
            return fragments
        }
        mutating 
        func render(declaration:[Language.Lexeme]) -> Frontend
        {
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
                        self.render(code: declaration)
                    }
                }
            }
        }
        // could be static 
        mutating 
        func introduction(for module:Module, blurb:Frontend?) -> Frontend
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
                    Frontend.span("Module")
                    {
                        ["kind"]
                    }
                    Frontend[.code]
                    {
                        ["package"]
                    }
                    content: 
                    {
                        module.package ?? "swift" 
                    }
                }
                Frontend[.h1]
                {
                    module.title
                }
                
                blurb ?? Frontend[.p]
                {
                    "No overview available."
                }
            }
        }
        mutating 
        func introduction(for symbol:Symbol, blurb:Frontend?) -> Frontend
        {
            var relationships:[Frontend] 
            if case _? = symbol.relationships.requirementOf
            {
                relationships = 
                [
                    Frontend[.li] 
                    {
                        Frontend[.p]
                        {
                            ["required"]
                        }
                        content:
                        {
                            "Required."
                        }
                    }
                ]
            }
            else 
            {
                relationships = []
            }
            if !symbol.extensionConstraints.isEmpty
            {
                relationships.append(Frontend[.li] 
                {
                    Frontend[.p]
                    {
                        "Available when "
                        self.render(constraints: symbol.extensionConstraints)
                    }
                })
            }
            let availability:[Frontend] = Biome.render(availability: symbol.availability)
            return Frontend[.section]
            {
                ["introduction"]
            }
            content:
            {
                self.biome.renderArticleEyebrows(symbol)
                
                Frontend[.h1]
                {
                    symbol.breadcrumbs.last
                }
                
                blurb ?? Frontend[.p]
                {
                    "No overview available."
                }
                
                if !relationships.isEmpty 
                {
                    Frontend[.ul]
                    {
                        ["relationships-list"]
                    }
                    content: 
                    {
                        relationships
                    }
                }
                if !availability.isEmpty 
                {
                    Frontend[.ul]
                    {
                        ["availability-list"]
                    }
                    content: 
                    {
                        availability
                    }
                }
            }
        }
        
        mutating 
        func content(markdown string:String) -> Comment
        {
            guard !string.isEmpty 
            else 
            {
                return (nil, [], [], [])
            }
            return self.content(markdown: Markdown.Document.init(parsing: string))
        }
        // expected parameters is unreliable, not available for subscripts
        private mutating 
        func content(markdown document:Markdown.Document) -> Comment
        {
            let content:[Frontend] = document.blockChildren.map { self.render(markup: $0) }
            let head:Frontend?
            let body:ArraySlice<Frontend>
            if  let first:Frontend = content.first, 
                case .container(.p, id: _, attributes: _, content: _) = first
            {
                head = first
                body = content.dropFirst()
            }
            else 
            {
                head = nil 
                body = content[...]
            }
            
            var parameters:[(name:String, comment:[Frontend])] = []
            var returns:[Frontend]      = []
            var discussion:[Frontend]   = []
            for block:Frontend in body 
            {
                // filter out top-level ‘ul’ blocks, since they may be special 
                guard case .container(.ul, id: let id, attributes: let attributes, content: let items) = block 
                else 
                {
                    discussion.append(block)
                    continue 
                }
                
                var ignored:[Frontend] = []
                for item:Frontend in items
                {
                    guard   case .container(.li, id: _, attributes: _, content: let content) = item, 
                            let (keywords, content):([String], [Frontend]) = Biome.keywords(prefixing: content)
                    else 
                    {
                        ignored.append(item)
                        continue 
                    }
                    // `keywords` always contains at least one keyword
                    let keyword:String = keywords[0]
                    magic:
                    switch keyword
                    {
                    case "parameters": 
                        guard keywords.count == 1 
                        else 
                        {
                            self.errors.append(ArticleAsideError.undefined(keywords: keywords))
                            break magic
                        }
                        guard let first:Frontend = content.first 
                        else 
                        {
                            self.errors.append(ArticleParametersError.empty(parameter: nil))
                            break magic
                        }
                        if let second:Frontend = content.dropFirst().first
                        {
                            self.errors.append(ArticleParametersError.duplicate(section: second))
                            break magic 
                        }
                        // look for a nested list 
                        guard case .container(.ul, id: _, attributes: _, content: let items) = first 
                        else 
                        {
                            self.errors.append(ArticleParametersError.invalid(section: first))
                            break magic
                        }
                        
                        for item:Frontend in items
                        {
                            guard   case .container(.li, id: _, attributes: _, content: let content) = item, 
                                    let (keywords, content):([String], [Frontend]) = Biome.keywords(prefixing: content), 
                                    let name:String = keywords.first, keyword.count == 1
                            else 
                            {
                                self.errors.append(ArticleParametersError.invalid(section: first))
                                break magic
                            }
                            parameters.append((name, content))
                        }
                        continue 
                        
                    case "parameter": 
                        guard keywords.count == 2 
                        else 
                        {
                            self.errors.append(ArticleAsideError.undefined(keywords: keywords))
                            break magic
                        }
                        let name:String = keywords[1]
                        if content.isEmpty
                        {
                            self.errors.append(ArticleParametersError.empty(parameter: name))
                            break magic
                        } 
                        parameters.append((name, content))
                        continue 
                    
                    case "returns":
                        guard keywords.count == 1 
                        else 
                        {
                            self.errors.append(ArticleAsideError.undefined(keywords: keywords))
                            break magic
                        }
                        if content.isEmpty
                        {
                            self.errors.append(ArticleReturnsError.empty)
                            break magic
                        }
                        if returns.isEmpty 
                        {
                            returns = content
                        }
                        else 
                        {
                            self.errors.append(ArticleReturnsError.duplicate(section: returns))
                            returns.append(contentsOf: content)
                        }
                        continue 
                    
                    case "tip", "note", "info", "warning", "throws", "important", "precondition", "complexity":
                        guard keywords.count == 1 
                        else 
                        {
                            self.errors.append(ArticleAsideError.undefined(keywords: keywords))
                            break magic
                        }
                        discussion.append(Frontend[.aside]
                        {
                            [keyword]
                        }
                        content:
                        {
                            Frontend[.h2]
                            {
                                keyword
                            }
                            
                            content
                        })
                        continue 
                        
                    default:
                        self.errors.append(ArticleAsideError.undefined(keywords: keywords))
                        break magic
                        /* if case _? = comment.complexity 
                        {
                            print("warning: detected multiple 'complexity' sections, only the last will be used")
                        }
                        guard   let first:Markdown.BlockMarkup = content.first, 
                                let first:Markdown.Paragraph = first as? Markdown.Paragraph
                        else 
                        {
                            print("warning: could not detect complexity function from section \(content)")
                            ignored.append(item)
                            continue 
                        }
                        let text:String = first.inlineChildren.map(\.plainText).joined()
                        switch text.firstIndex(of: ")").map(text.prefix(through:))
                        {
                        case "O(1)"?: 
                            comment.complexity = .constant
                        case "O(n)"?, "O(m)"?: 
                            comment.complexity = .linear
                        case "O(n log n)"?: 
                            comment.complexity = .logLinear
                        default:
                            print("warning: could not detect complexity function from string '\(text)'")
                            ignored.append(item)
                            continue 
                        } */
                    }
                    
                    ignored.append(item)
                }
                guard ignored.isEmpty 
                else 
                {
                    discussion.append(.container(.ul, id: id, attributes: attributes, content: ignored))
                    continue 
                }
            }
            
            return (head, parameters, returns, discussion)
        }
        private mutating  
        func render(markup:Markdown.Markup) -> Frontend
        {
            let container:HTML.Container 
            switch markup 
            {
            case is Markdown.LineBreak:             return Frontend[.br]
            case is Markdown.SoftBreak:             return Frontend.text(escaped: " ")
            case is Markdown.ThematicBreak:         return Frontend[.hr]
            case let node as Markdown.CustomInline: return Frontend.text(escaping: node.text)
            case let node as Markdown.Text:         return Frontend.text(escaping: node.string)
            case let node as Markdown.HTMLBlock:    return Frontend.text(escaped: node.rawHTML)
            case let node as Markdown.InlineHTML:   return Frontend.text(escaped: node.rawHTML)
            
            case is Markdown.Document:          container = .main
            case is Markdown.BlockQuote:        container = .blockquote
            case is Markdown.Emphasis:          container = .em
            case let node as Markdown.Heading: 
                switch node.level 
                {
                case 1:                         container = .h2
                case 2:                         container = .h3
                case 3:                         container = .h4
                case 4:                         container = .h5
                default:                        container = .h6
                }
            case is Markdown.ListItem:          container = .li
            case is Markdown.OrderedList:       container = .ol
            case is Markdown.Paragraph:         container = .p
            case is Markdown.Strikethrough:     container = .s
            case is Markdown.Strong:            container = .strong
            case is Markdown.Table:             container = .table
            case is Markdown.Table.Row:         container = .tr
            case is Markdown.Table.Head:        container = .thead
            case is Markdown.Table.Body:        container = .tbody
            case is Markdown.Table.Cell:        container = .td
            case is Markdown.UnorderedList:     container = .ul
            
            case let node as Markdown.CodeBlock: 
                return Frontend[.pre]
                {
                    ["notebook"]
                }
                content:
                {
                    Frontend[.code]
                    {
                        Biome.render(lexeme: .newlines(0))
                        Biome.render(code: Language.highlight(code: node.code))
                    }
                }
            case let node as Markdown.InlineCode: 
                return Frontend[.code]
                {
                    node.code
                }

            case is Markdown.BlockDirective: 
                return Frontend[.div]
                {
                    "(unsupported block directive)"
                }
            
            case let node as Markdown.Image: 
                // TODO: do something with these
                let _:String?       = node.title 
                let _:[Frontend]    = node.children.map 
                {
                    self.render(markup: $0)
                }
                guard let source:String = node.source
                else 
                {
                    self.errors.append(ArticleContentError.missingImageSource)
                    return Frontend[.img]
                }
                return Frontend[.img]
                {
                    (source, as: HTML.Src.self)
                }
            
            case let node as Markdown.Link: 
                let display:[Frontend] = node.children.map 
                {
                    self.render(markup: $0)
                }
                guard let target:String = node.destination
                else 
                {
                    self.errors.append(ArticleContentError.missingLinkDestination)
                    return Frontend[.span]
                    {
                        display
                    }
                }
                return Frontend[.a]
                {
                    (target, as: HTML.Href.self)
                    HTML.Target._blank
                    HTML.Rel.nofollow
                }
                content:
                {
                    display
                }
                
            case let node as Markdown.SymbolLink: 
                guard let path:String = node.destination
                else 
                {
                    self.errors.append(ArticleSymbolLinkError.empty)
                    return Frontend[.code]
                    {
                        "<empty symbol path>"
                    }
                }
                return Frontend[.code]
                {
                    path
                }
                
            case let node: 
                self.errors.append(ArticleContentError.unsupported(markup: node))
                return Frontend[.div]
                {
                    "(unsupported markdown node '\(type(of: node))')"
                }
            }
            return Frontend[container]
            {
                markup.children.map
                {
                    self.render(markup: $0)
                }
            }
        }
    }
}
