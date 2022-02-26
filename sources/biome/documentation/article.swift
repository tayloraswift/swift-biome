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
    
    func page(for module:Module.Index, article:Article, articles:[Article]) -> Resource
    {
        let dynamic:Frontend = Frontend[.div]
        {
            ["lower-container"]
        }
        content:
        {
            self.render(topics: self.modules[module].topics, heading: "Symbols", articles: articles)
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
                        (self[item.index].path.canonical, as: HTML.Href.self)
                    }
                    content: 
                    {
                        Self.render(code: self[item.index].qualified)
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
                        self.render(constraints: item.conditions)
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
    
    struct Article 
    {
        let navigator:Frontend
        let card:Frontend
        let full:Frontend
    }
    
    func article(for module:Module.Index, comment:String) -> Article
    {
        let card:Frontend       = Frontend[.li] 
        { 
            self.modules[module].title 
        }
        let navigator:Frontend  = Frontend[.ol] 
        {
            ["breadcrumbs-container"]
        }
        content:
        {
            card
        }
        let comment:Comment = comment.isEmpty ? (nil, [], [], [], []) as Comment :
            self.decode(markdown: Markdown.Document.init(parsing: comment))
        let full:Frontend   = Frontend[.article]
        {
            ["upper-container-left"]
        }
        content: 
        {
            self.renderArticleIntroduction(self.modules[module], blurb: comment.head)
            self.renderArticleDeclaration(self.modules[module].declaration)
            // these shouldn’t usually be here, but if for some reason, someone 
            // writes a module doc that has these fields, print them instead of 
            // discarding them.
            self.renderArticleParameters(comment.parameters)
            self.renderArticleSection(comment.returns, heading: "Returns", class: "returns")
            self.renderArticleSection(comment.discussion, heading: "Overview", class: "discussion")
        }
        return .init(navigator: .text(escaped: navigator.rendered), 
            card: .text(escaped: card.rendered), 
            full: .text(escaped: full.rendered))
    }
    func article(for symbol:Int, comment:String) -> Article
    {
        var breadcrumbs:[Frontend]  = [ Frontend[.li] { self[symbol].breadcrumbs.last } ]
        var next:Int?               = self[symbol].breadcrumbs.parent
        while let index:Int         = next
        {
            breadcrumbs.append(Frontend[.li]
            {
                Frontend.link(self[index].breadcrumbs.last, to: self[index].path.canonical, internal: true)
            })
            next = self[index].breadcrumbs.parent
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
        let comment:Comment = comment.isEmpty ? (nil, [], [], [], []) as Comment :
            self.decode(markdown: Markdown.Document.init(parsing: comment))
        let card:Frontend   = self.renderArticleCard(self[symbol], blurb: comment.head)
        let full:Frontend   = Frontend[.article]
        {
            ["upper-container-left"]
        }
        content: 
        {
            self.renderArticleIntroduction(self[symbol], blurb: comment.head)
            self.renderArticlePlatforms(self[symbol].availability)
            self.renderArticleDeclaration(self[symbol].declaration)
            self.renderArticleParameters(comment.parameters)
            self.renderArticleSection(comment.returns, heading: "Returns", class: "returns")
            self.renderArticleSection(comment.discussion, heading: "Overview", class: "discussion")
        }
        return .init(navigator: .text(escaped: navigator.rendered), 
            card: .text(escaped: card.rendered), 
            full: .text(escaped: full.rendered))
    }
    
    private 
    func renderArticleCard(_ symbol:Symbol, blurb:Frontend?) -> Frontend
    {
        var relationships:[Frontend]    = []
        if let overridden:Int           = symbol.relationships.overrideOf
        {
            guard let interface:Int = self[overridden].breadcrumbs.parent 
            else 
            {
                fatalError("unimplemented: parent of overridden symbol '\(self[overridden].title)' does not exist")
            }
            let prose:String
            if case .protocol = self[interface].kind
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
                            (self[overridden].path.canonical, as: HTML.Href.self)
                        }
                        content: 
                        {
                            Self.render(code: self[interface].qualified)
                        }
                    }
                }
            })
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
        
        let availability:[Frontend] = Self.renderAvailability(
            everywhere: symbol.availability[.wildcard],
            swift: symbol.availability[.swift])
            
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
    func renderArticleIntroduction(_ module:Module, blurb:Frontend?) -> Frontend
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
    private 
    func renderArticleIntroduction(_ symbol:Symbol, blurb:Frontend?) -> Frontend
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
        let availability:[Frontend] = Self.renderAvailability(
            everywhere: symbol.availability[.wildcard],
            swift: symbol.availability[.swift])
        return Frontend[.section]
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
                Frontend[.span]
                {
                    ["module"]
                }
                content: 
                {
                    if let extended:Module.Index = symbol.bystander
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
                /* else 
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
                } */
            }
            Frontend[.h1]
            {
                symbol.title
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
    private 
    func renderArticlePlatforms(_ availability:[Symbol.Domain: Symbol.Availability]) -> Frontend?
    {
        let platforms:[(Symbol.Domain, Version)] = 
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
            if let version:Version = availability[$0]?.introduced 
            {
                return ($0, version)
            }
            else 
            {
                return nil 
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
                for (platform, version):(Symbol.Domain, Version) in platforms 
                {
                    Frontend[.li]
                    {
                        "\(platform.rawValue) "
                        Frontend.span("\(version.description)+")
                        {
                            ["version"]
                        }
                    }
                }
            }
        }
    }
    private 
    func renderArticleDeclaration(_ declaration:[Language.Lexeme]) -> Frontend
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
    private 
    func renderArticleSection(_ content:[Frontend], heading:String, class:String) -> Frontend?
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
    private 
    func renderArticleParameters(_ parameters:[(name:String, comment:[Frontend])]) -> Frontend?
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
    private static 
    func renderAvailability(everywhere:Symbol.Availability?, swift:Symbol.Availability?) -> [Frontend]
    {
        var availabilities:[Frontend] = []
        if let availability:Symbol.Availability = everywhere
        {
            if availability.unavailable 
            {
                // unconditionally unavailable 
                availabilities.append(Self.renderAvailability("Unavailable"))
            }
            if case nil? = availability.deprecated 
            {
                // unconditionally deprecated
                availabilities.append(Self.renderAvailability("Deprecated"))
            }
        }
        if let availability:Symbol.Availability = swift
        {
            if let version:Version = availability.introduced
            {
                availabilities.append(Self.renderAvailability("Available", since: ("Swift", version)))
            }
            if availability.unavailable 
            {
                // unconditionally unavailable 
                availabilities.append(Self.renderAvailability("Unavailable"))
            }
            if let version:Version? = availability.deprecated 
            {
                if let version:Version = version 
                {
                    availabilities.append(Self.renderAvailability("Deprecated", since: ("Swift", version)))
                }
                else 
                {
                    availabilities.append(Self.renderAvailability("Deprecated"))
                }
            }
            if let version:Version = availability.obsoleted 
            {
                availabilities.append(Self.renderAvailability("Obsolete", since: ("Swift", version)))
            } 
        }
        return availabilities
    }
    private static 
    func renderAvailability(_ adjective:String, since:(domain:String, version:Version)? = nil) -> Frontend
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
}
