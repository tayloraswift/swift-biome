import Markdown
import Resource
import StructuredDocument
import HTML

extension Biome 
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
    
    func page(package:Int, article:Article) -> Resource
    {
        typealias Element   = HTML.Element<Anchor>
        let dynamic:Element = Element[.div]
        {
            ["lower-container"]
        }
        content:
        {
            Element[.section]
            {
                ["relationships"]
            }
            content: 
            {
                Element[.h2]
                {
                    "Modules"
                }
                Element[.ul]
                {
                    for module:Int in self.packages[package].modules
                    {
                        Element[.li]
                        {
                            Element[.code]
                            {
                                ["signature"]
                            }
                            content: 
                            {
                                Element[.a]
                                {
                                    (self.modules[module].path.canonical, as: HTML.Href.self)
                                }
                                content: 
                                {
                                    Self.render(lexeme: .code(self.modules[module].id.identifier, class: .identifier))
                                }
                            }
                        }
                    }
                }
            }
        }
        return Self.page(title: self.packages[package].name, article: article, dynamic: dynamic)
    }
    func page(module:Int, article:Article, articles:[Article]) -> Resource
    {
        typealias Element   = HTML.Element<Anchor>
        let dynamic:Element = Element[.div]
        {
            ["lower-container"]
        }
        content:
        {
            self.render(topics: self.modules[module].topics.members, heading: "Members", articles: articles)
            self.render(topics: self.modules[module].topics.removed, heading: "Removed Members", articles: articles)
        }
        return Self.page(title: self.modules[module].title, article: article, dynamic: dynamic)
    }
    func page(symbol index:Int, articles:[Article]) -> Resource
    {
        typealias Element   = HTML.Element<Anchor>
        let symbol:Symbol   = self.symbols[index]
        let dynamic:Element = Element[.div]
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
        return Self.page(title: symbol.title, article: articles[index], dynamic: dynamic)
    }
    private static 
    func page(title:String, article:Article, dynamic:HTML.Element<Anchor>) -> Resource
    {
        typealias Element = HTML.Element<Anchor>
        let document:DocumentRoot<HTML, Anchor> = .init 
        {
            HTML.Lang.en
        }
        content:
        {
            Element[.head]
            {
                Element[.title] 
                {
                    title
                }
                Element.metadata(charset: Unicode.UTF8.self)
                Element.metadata 
                {
                    ("viewport", "width=device-width, initial-scale=1")
                }
                
                Element[.link] 
                {
                    ("https://fonts.googleapis.com", as: HTML.Href.self)
                    HTML.Rel.preconnect 
                }
                Element[.link] 
                {
                    HTML.Crossorigin.anonymous 
                    ("https://fonts.gstatic.com", as: HTML.Href.self)
                    HTML.Rel.preconnect 
                }
                Element[.link] 
                {
                    ("https://fonts.googleapis.com/css2?family=Literata:ital,wght@0,400;0,600;1,400;1,600&display=swap", as: HTML.Href.self)
                    HTML.Rel.stylesheet 
                }
                Element[.script]
                {
                    ("/lunr.js", as: HTML.Src.self)
                    (true, as: HTML.Defer.self)
                }
                Element[.script]
                {
                    ("/search.js", as: HTML.Src.self)
                    (true, as: HTML.Defer.self)
                }
                Element[.link]
                {
                    ("/biome.css", as: HTML.Href.self)
                    HTML.Rel.stylesheet
                }
                Element[.link]
                {
                    ("/favicon.png", as: HTML.Href.self)
                    HTML.Rel.icon
                }
                Element[.link]
                {
                    ("/favicon.ico", as: HTML.Href.self)
                    HTML.Rel.icon
                    Resource.Binary.icon
                }
            }
            Element[.body]
            {
                ["documentation"]
            }
            content: 
            {
                Element[.nav]
                {
                    Element[.div]
                    {
                        ["breadcrumbs"]
                    } 
                    content: 
                    {
                        article.navigator
                    }
                    Element[.div]
                    {
                        ["search-bar"]
                    } 
                    content: 
                    {
                        Element[.form, id: .search] 
                        {
                            HTML.Role.search
                        }
                        content: 
                        {
                            Element[.div]
                            {
                                ["input-container"]
                            }
                            content: 
                            {
                                Element[.div]
                                {
                                    ["bevel"]
                                }
                                Element[.div]
                                {
                                    ["rectangle"]
                                }
                                content: 
                                {
                                    Element[.input, id: .searchInput]
                                    {
                                        HTML.InputType.search
                                        HTML.Autocomplete.off
                                        // (true, as: HTML.Autofocus.self)
                                        ("search symbols", as: HTML.Placeholder.self)
                                    }
                                }
                                Element[.div]
                                {
                                    ["bevel"]
                                }
                            }
                            Element[.ol, id: .searchResults]
                        }
                    }
                }
                Element[.main]
                {
                    Element[.div]
                    {
                        ["upper"]
                    }
                    content: 
                    {
                        Element[.div]
                        {
                            ["upper-container"]
                        }
                        content: 
                        {
                            article.full
                        }
                    }
                    Element[.div]
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
    func render<S>(list types:S, heading:String) -> HTML.Element<Anchor>?
        where S:Sequence, S.Element == (index:Int, conditions:[Language.Constraint])
    {
        typealias Element = HTML.Element<Anchor>
        // we will discard all errors from dynamic rendering
        var renderer:DiagnosticRenderer = .init(biome: self, errors: [])
        let list:[Element] = types.map 
        {
            (item:(index:Int, conditions:[Language.Constraint])) in 
            Element[.li]
            {
                Element[.code]
                {
                    ["signature"]
                }
                content: 
                {
                    Element[.a]
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
                    Element[.p]
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
        return Element[.section]
        {
            ["relationships"]
        }
        content: 
        {
            Element[.h2]
            {
                heading
            }
            Element[.ul]
            {
                list
            }
        }
    }
    private 
    func render<S>(topics:S, heading:String, articles:[Article]) -> HTML.Element<Anchor>?
        where S:Sequence, S.Element == (heading:Topic, indices:[Int])
    {
        typealias Element = HTML.Element<Anchor>
        let topics:[Element] = topics.map
        {
            (topic:(heading:Topic, indices:[Int])) in 
            Element[.div]
            {
                ["topic-container"]
            }
            content:
            {
                Element[.div]
                {
                    ["topic-container-left"]
                }
                content:
                {
                    Element[.h3]
                    {
                        topic.heading.description
                    }
                }
                Element[.ul]
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
        return Element[.section]
        {
            ["topics"]
        }
        content: 
        {
            Element[.h2]
            {
                heading
            }
            topics
        }
    }
    
    typealias Comment =
    (
        head:HTML.Element<Anchor>?, 
        parameters:[(name:String, comment:[HTML.Element<Anchor>])],
        returns:[HTML.Element<Anchor>],
        discussion:[HTML.Element<Anchor>]
    )
    
    struct Article 
    {
        typealias Element = HTML.Element<Anchor>
        var navigator:Element
        {
            .text(escaped: self.baked.navigator)
        }
        var card:Element
        {
            .text(escaped: self.baked.card)
        }
        var full:Element
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
    
    func article(package index:Int, comment:String) -> Article
    {
        typealias Element       = HTML.Element<Anchor>
        let card:Element        = Element[.li] 
        { 
            self.packages[index].name 
        }
        let navigator:Element   = Element[.ol] 
        {
            ["breadcrumbs-container"]
        }
        content:
        {
            card
        }
        var renderer:DiagnosticRenderer = .init(biome: self, errors: [])
        let comment:Comment = renderer.content(markdown: comment)
        let full:Element = Element[.article]
        {
            ["upper-container-left"]
        }
        content: 
        {
            renderer.introduction(for: self.packages[index], blurb: comment.head)
            renderer.render(declaration: [])
            // these shouldn’t usually be here, but if for some reason, someone 
            // writes a package doc that has these fields, print them instead of 
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
    func article(module index:Int, comment:String) -> Article
    {
        typealias Element       = HTML.Element<Anchor>
        let card:Element        = Element[.li] 
        { 
            self.modules[index].title 
        }
        let navigator:Element   = Element[.ol] 
        {
            ["breadcrumbs-container"]
        }
        content:
        {
            card
        }
        var renderer:DiagnosticRenderer = .init(biome: self, errors: [])
        let comment:Comment = renderer.content(markdown: comment)
        let full:Element = Element[.article]
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
        typealias Element           = HTML.Element<Anchor>
        let symbol:Symbol           = self.symbols[index]
        
        var breadcrumbs:[Element]   = [ Element[.li] { symbol.breadcrumbs.last } ]
        var next:Int?               = symbol.breadcrumbs.parent
        while let index:Int         = next
        {
            breadcrumbs.append(Element[.li]
            {
                Element.link(self.symbols[index].breadcrumbs.last, to: self.symbols[index].path.canonical, internal: true)
            })
            next = self.symbols[index].breadcrumbs.parent
        }
        breadcrumbs.reverse()
        
        let navigator:Element  = Element[.ol] 
        {
            ["breadcrumbs-container"]
        }
        content:
        {
            breadcrumbs
        }
        
        var renderer:DiagnosticRenderer = .init(biome: self, errors: [])
        let comment:Comment = renderer.content(markdown: comment)
        
        let card:Element   = self.renderArticleCard(symbol, blurb: comment.head)
        let full:Element   = Element[.article]
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
    func renderArticleCard(_ symbol:Symbol, blurb:HTML.Element<Anchor>?) -> HTML.Element<Anchor>
    {
        typealias Element               = HTML.Element<Anchor>
        var relationships:[Element]     = []
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
            relationships.append(Element[.li]
            {
                Element[.p]
                {
                    prose 
                    Element[.code]
                    {
                        Element[.a]
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
            relationships.append(Element[.li] 
            {
                Element[.p]
                {
                    "Available when "
                    self.render(constraints: symbol.extensionConstraints)
                }
            })
        } */
        
        let availability:[Element] = Self.render(availability: symbol.availability)
        return Element[.li]
        {
            Element[.code]
            {
                ["signature"]
            }
            content: 
            {
                Element[.a]
                {
                    (symbol.path.canonical, as: HTML.Href.self)
                }
                content: 
                {
                    Self.render(code: symbol.signature)
                }
            }
            if let blurb:Element = blurb 
            {
                blurb
            }
            if !relationships.isEmpty 
            {
                Element[.ul]
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
                Element[.ul]
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
    func renderArticleEyebrows(_ symbol:Symbol) -> HTML.Element<Anchor> 
    {
        typealias Element = HTML.Element<Anchor>
        return Element[.div]
        {
            ["eyebrows"]
        }
        content:
        {
            Element.span(symbol.kind.title)
            {
                ["kind"]
            }
            Element[.span]
            {
                ["module"]
            }
            content: 
            {
                if let extended:Int = symbol.bystander
                {
                    Element[.span]
                    {
                        ["extended"]
                    }
                    content:
                    {
                        Element.link(self.modules[extended].title, to: self.modules[extended].path.canonical, internal: true)
                    }
                }
                Element.link(self.modules[symbol.module].title, to: self.modules[symbol.module].path.canonical, internal: true)
            }
        }
    }

    private static 
    func render(availability:(unconditional:Symbol.UnconditionalAvailability?, swift:Symbol.SwiftAvailability?)) -> [HTML.Element<Anchor>]
    {
        typealias Element = HTML.Element<Anchor>
        var availabilities:[Element] = []
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
    func render(availability adjective:String, since:(domain:String, version:Version)? = nil) -> HTML.Element<Anchor>
    {
        typealias Element = HTML.Element<Anchor>
        return Element[.li]
        {
            Element[.p]
            {
                Element[.strong]
                {
                    adjective
                }
                if let (domain, version):(String, Version) = since 
                {
                    " since \(domain) "
                    Element.span(version.description)
                    {
                        ["version"]
                    }
                }
            }
        }
    }
    
    static 
    func render(code:[Language.Lexeme]) -> [HTML.Element<Anchor>] 
    {
        code.map(Self.render(lexeme:))
    }
    static 
    func render(lexeme:Language.Lexeme) -> HTML.Element<Anchor>
    {
        typealias Element = HTML.Element<Anchor>
        switch lexeme
        {
        case .code(let text, class: let classification):
            let css:String
            switch classification 
            {
            case .punctuation: 
                return Element.text(escaping: text)
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
            return Element.span(text)
            {
                [css]
            }
        case .comment(let text, documentation: _):
            return Element.span(text)
            {
                ["syntax-comment"]
            } 
        case .invalid(let text):
            return Element.span(text)
            {
                ["syntax-invalid"]
            } 
        case .newlines(let count):
            return Element.span(String.init(repeating: "\n", count: count))
            {
                ["syntax-newline"]
            } 
        case .spaces(let count):
            return Element.text(escaped: String.init(repeating: " ", count: count)) 
        }
    }
    
    private static
    func render(platforms availability:[Symbol.Domain: Symbol.Availability]) 
        -> HTML.Element<Anchor>?
    {
        typealias Element = HTML.Element<Anchor>
        var platforms:[Element] = []
        for platform:Symbol.Domain in Symbol.Domain.platforms 
        {
            if let availability:Symbol.Availability = availability[platform]
            {
                if availability.unavailable 
                {
                    platforms.append(Element[.li]
                    {
                        "\(platform.rawValue) unavailable"
                    })
                }
                else if case nil? = availability.deprecated 
                {
                    platforms.append(Element[.li]
                    {
                        "\(platform.rawValue) deprecated"
                    })
                }
                else if case let version?? = availability.deprecated 
                {
                    platforms.append(Element[.li]
                    {
                        "\(platform.rawValue) deprecated since "
                        Element.span("\(version.description)")
                        {
                            ["version"]
                        }
                    })
                }
                else if let version:Version = availability.introduced 
                {
                    platforms.append(Element[.li]
                    {
                        "\(platform.rawValue) "
                        Element.span("\(version.description)+")
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
        return Element[.section]
        {
            ["platforms"]
        }
        content: 
        {
            Element[.ul]
            {
                platforms
            }
        }
    }
    private static 
    func render(section content:[HTML.Element<Anchor>], heading:String, class:String) 
        -> HTML.Element<Anchor>?
    {
        typealias Element = HTML.Element<Anchor>
        guard !content.isEmpty 
        else 
        {
            return nil 
        }
        return Element[.section]
        {
            [`class`]
        }
        content: 
        {
            Element[.h2]
            {
                heading
            }
            content
        }
    }
    private static 
    func render(parameters:[(name:String, comment:[HTML.Element<Anchor>])])
        -> HTML.Element<Anchor>?
    {
        typealias Element = HTML.Element<Anchor>
        guard !parameters.isEmpty 
        else 
        {
            return nil 
        }
        return Element[.section]
        {
            ["parameters"]
        }
        content: 
        {
            Element[.h2]
            {
                "Parameters"
            }
            Element[.dl]
            {
                for (name, comment):(String, [Element]) in parameters 
                {
                    Element[.dt]
                    {
                        name
                    }
                    Element[.dd]
                    {
                        comment
                    }
                }
            }
        }
    }
    
    struct DiagnosticRenderer 
    {
        typealias Element = HTML.Element<Anchor>
        
        let biome:Biome 
        var errors:[Error]
        
        mutating 
        func render(code:[Language.Lexeme]) -> [Element] 
        {
            code.map 
            {
                self.render(lexeme: $0)
            }
        }
        mutating 
        func render(lexeme:Language.Lexeme) -> Element
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
            return Element.link(text, to: path.canonical, internal: true)
            {
                ["syntax-type"] 
            }
        }
        mutating 
        func render(constraint:Language.Constraint) -> [Element] 
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
                    Element[.code]
                    {
                        self.render(lexeme: subject)
                    },
                    Element.text(escaped: prose), 
                    Element[.code]
                    {
                        self.render(lexeme: .code(constraint.object, class: .type(object)))
                    },
                ]
        }
        mutating 
        func render(constraints:[Language.Constraint]) -> [Element] 
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
            var fragments:[Element]
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
        func render(declaration:[Language.Lexeme]) -> Element
        {
            Element[.section]
            {
                ["declaration"]
            }
            content:
            {
                Element[.h2]
                {
                    "Declaration"
                }
                Element[.pre]
                {
                    Element[.code] 
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
        func introduction(for package:Package, blurb:Element?) -> Element
        {
            Element[.section]
            {
                ["introduction"]
            }
            content:
            {
                Element[.div]
                {
                    ["eyebrows"]
                }
                content:
                {
                    if case .swift = package.id 
                    {
                        Element.span("Standard Library")
                        {
                            ["kind"]
                        }
                    }
                    else 
                    {
                        Element.span("Package")
                        {
                            ["kind"]
                        }
                    }
                }
                Element[.h1]
                {
                    package.name
                }
                
                blurb ?? Element[.p]
                {
                    "No overview available."
                }
            }
        }
        // could be static 
        mutating 
        func introduction(for module:Module, blurb:Element?) -> Element
        {
            Element[.section]
            {
                ["introduction"]
            }
            content:
            {
                Element[.div]
                {
                    ["eyebrows"]
                }
                content:
                {
                    Element.span("Module")
                    {
                        ["kind"]
                    }
                    Element[.span]
                    {
                        ["package"]
                    }
                    content:
                    {
                        Element.link(self.biome.packages[module.package].name, 
                            to: self.biome.packages[module.package].path.canonical, 
                            internal: true)
                    }
                }
                Element[.h1]
                {
                    module.title
                }
                
                blurb ?? Element[.p]
                {
                    "No overview available."
                }
            }
        }
        mutating 
        func introduction(for symbol:Symbol, blurb:Element?) -> Element
        {
            var relationships:[Element] 
            if case _? = symbol.relationships.requirementOf
            {
                relationships = 
                [
                    Element[.li] 
                    {
                        Element[.p]
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
                relationships.append(Element[.li] 
                {
                    Element[.p]
                    {
                        "Available when "
                        self.render(constraints: symbol.extensionConstraints)
                    }
                })
            }
            let availability:[Element] = Biome.render(availability: symbol.availability)
            return Element[.section]
            {
                ["introduction"]
            }
            content:
            {
                self.biome.renderArticleEyebrows(symbol)
                
                Element[.h1]
                {
                    symbol.breadcrumbs.last
                }
                
                blurb ?? Element[.p]
                {
                    "No overview available."
                }
                
                if !relationships.isEmpty 
                {
                    Element[.ul]
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
                    Element[.ul]
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
            let content:[Element] = document.blockChildren.map { self.render(markup: $0) }
            let head:Element?
            let body:ArraySlice<Element>
            if  let first:Element = content.first, 
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
            
            var parameters:[(name:String, comment:[Element])] = []
            var returns:[Element]      = []
            var discussion:[Element]   = []
            for block:Element in body 
            {
                // filter out top-level ‘ul’ blocks, since they may be special 
                guard case .container(.ul, id: let id, attributes: let attributes, content: let items) = block 
                else 
                {
                    discussion.append(block)
                    continue 
                }
                
                var ignored:[Element] = []
                for item:Element in items
                {
                    guard   case .container(.li, id: _, attributes: _, content: let content) = item, 
                            let (keywords, content):([String], [Element]) = Biome.keywords(prefixing: content)
                    else 
                    {
                        ignored.append(item)
                        continue 
                    }
                    // `keywords` always contains at least one keyword
                    let keyword:String = keywords[0]
                    do 
                    {
                        switch keyword
                        {
                        case "parameters": 
                            guard keywords.count == 1 
                            else 
                            {
                                throw ArticleAsideError.undefined(keywords: keywords)
                            }
                            parameters.append(contentsOf: try Self.parameters(in: content))
                            
                        case "parameter": 
                            guard keywords.count == 2 
                            else 
                            {
                                throw ArticleAsideError.undefined(keywords: keywords)
                            }
                            let name:String = keywords[1]
                            if content.isEmpty
                            {
                                throw ArticleParametersError.empty(parameter: name)
                            } 
                            parameters.append((name, content))
                        
                        case "returns":
                            guard keywords.count == 1 
                            else 
                            {
                                throw ArticleAsideError.undefined(keywords: keywords)
                            }
                            if content.isEmpty
                            {
                                throw ArticleReturnsError.empty
                            }
                            if returns.isEmpty 
                            {
                                returns = content
                            }
                            else 
                            {
                                throw ArticleReturnsError.duplicate(section: returns)
                            }
                        
                        case "tip", "note", "info", "warning", "throws", "important", "precondition", "complexity":
                            guard keywords.count == 1 
                            else 
                            {
                                throw ArticleAsideError.undefined(keywords: keywords)
                            }
                            discussion.append(Element[.aside]
                            {
                                [keyword]
                            }
                            content:
                            {
                                Element[.h2]
                                {
                                    keyword
                                }
                                
                                content
                            })
                            
                        default:
                            throw ArticleAsideError.undefined(keywords: keywords)
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
                    }
                    catch let error 
                    {
                        self.errors.append(error)
                        ignored.append(item)
                    }
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
        private static
        func parameters(in content:[Element]) throws -> [(name:String, comment:[Element])]
        {
            guard let first:Element = content.first 
            else 
            {
                throw ArticleParametersError.empty(parameter: nil)
            }
            // look for a nested list 
            guard case .container(.ul, id: _, attributes: _, content: let items) = first 
            else 
            {
                throw ArticleParametersError.invalidList(first)
            }
            if case _? = content.dropFirst().first
            {
                throw ArticleParametersError.multipleLists(content)
            }
            
            var parameters:[(name:String, comment:[Element])] = []
            for item:Element in items
            {
                guard   case .container(.li, id: _, attributes: _, content: let content) = item, 
                        let (keywords, content):([String], [Element]) = Biome.keywords(prefixing: content), 
                        let name:String = keywords.first, keywords.count == 1
                else 
                {
                    throw ArticleParametersError.invalidListItem(item)
                }
                parameters.append((name, content))
            }
            return parameters
        }
        private mutating  
        func render(markup:Markdown.Markup) -> Element
        {
            let container:HTML.Container 
            switch markup 
            {
            case is Markdown.LineBreak:             return Element[.br]
            case is Markdown.SoftBreak:             return Element.text(escaped: " ")
            case is Markdown.ThematicBreak:         return Element[.hr]
            case let node as Markdown.CustomInline: return Element.text(escaping: node.text)
            case let node as Markdown.Text:         return Element.text(escaping: node.string)
            case let node as Markdown.HTMLBlock:    return Element.text(escaped: node.rawHTML)
            case let node as Markdown.InlineHTML:   return Element.text(escaped: node.rawHTML)
            
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
                return Element[.pre]
                {
                    ["notebook"]
                }
                content:
                {
                    Element[.code]
                    {
                        Biome.render(lexeme: .newlines(0))
                        Biome.render(code: Language.highlight(code: node.code))
                    }
                }
            case let node as Markdown.InlineCode: 
                return Element[.code]
                {
                    node.code
                }

            case is Markdown.BlockDirective: 
                return Element[.div]
                {
                    "(unsupported block directive)"
                }
            
            case let node as Markdown.Image: 
                // TODO: do something with these
                let _:String?       = node.title 
                let _:[Element]    = node.children.map 
                {
                    self.render(markup: $0)
                }
                guard let source:String = node.source
                else 
                {
                    self.errors.append(ArticleContentError.missingImageSource)
                    return Element[.img]
                }
                return Element[.img]
                {
                    (source, as: HTML.Src.self)
                }
            
            case let node as Markdown.Link: 
                let display:[Element] = node.children.map 
                {
                    self.render(markup: $0)
                }
                guard let target:String = node.destination
                else 
                {
                    self.errors.append(ArticleContentError.missingLinkDestination)
                    return Element[.span]
                    {
                        display
                    }
                }
                return Element[.a]
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
                    return Element[.code]
                    {
                        "<empty symbol path>"
                    }
                }
                return Element[.code]
                {
                    path
                }
                
            case let node: 
                self.errors.append(ArticleContentError.unsupported(markup: node))
                return Element[.div]
                {
                    "(unsupported markdown node '\(type(of: node))')"
                }
            }
            return Element[container]
            {
                markup.children.map
                {
                    self.render(markup: $0)
                }
            }
        }
    }
}
