import Resource
import StructuredDocument
import HTML

extension Biome 
{
    enum Anchor:DocumentID, Hashable, Sendable
    {
        case card(Documentation.Index)
        
        case navigator
        case introduction
        case summary
        case platforms
        case declaration
        case discussion
        
        case search
        case searchInput
        case searchResults
        
        public 
        var documentId:String 
        {
            switch self 
            {
            case .search:           return "search"
            case .searchInput:      return "search-input"
            case .searchResults:    return "search-results"
            default: 
                fatalError("unreachable")
            }
        }
    }
    
    func page(package:Int, article:Article, filter:[Package.ID]) -> Resource
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
                                    (self.modules[module].path.description, as: HTML.Href.self)
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
        return Self.page(title: self.packages[package].name, substitutions: article.substitutions, filter: filter, dynamic: dynamic)
    }
    func page(module:Int, article:Article, articles:[Article], filter:[Package.ID]) -> Resource
    {
        typealias Element = HTML.Element<Anchor>
        
        var references:Set<Int> = []
        let dynamic:Element = Element[.div]
        {
            ["lower-container"]
        }
        content:
        {
            self.render(topics: self.modules[module].topics.members, heading: "Members", 
                articles: articles, 
                references: &references)
            self.render(topics: self.modules[module].topics.removed, heading: "Removed Members", 
                articles: articles, 
                references: &references)
        }
        var substitutions:[Anchor: Element] = article.substitutions
        for reference:Int in references 
        {
            substitutions[.card(.symbol(reference))] = articles[reference].summary
        }
        return Self.page(title: self.modules[module].title, substitutions: substitutions, filter: filter, dynamic: dynamic)
    }
    func page(symbol index:Int, articles:[Article], filter:[Package.ID]) -> Resource
    {
        typealias Element = HTML.Element<Anchor>
        let symbol:Symbol = self.symbols[index]
        
        var references:Set<Int> = []
        let dynamic:Element     = Element[.div]
        {
            ["lower-container"]
        }
        content:
        {
            if case .protocol(let abstract) = symbol.relationships 
            {
                self.render(list: abstract.downstream.map { ($0, []) }, heading: "Refinements")
            }
            
            self.render(topics: symbol.topics.requirements, heading: "Requirements", 
                articles: articles, 
                references: &references)
            self.render(topics: symbol.topics.members,      heading: "Members", 
                articles: articles, 
                references: &references)
            
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
            self.render(topics: symbol.topics.removed,      heading: "Removed Members", 
                articles: articles, 
                references: &references)
        }
        var substitutions:[Anchor: Element] = articles[index].substitutions
        if  let origin:Int = symbol.commentOrigin
        {
            substitutions[.summary]     = articles[origin].summary
            substitutions[.discussion]  = articles[origin].discussion
        }
        if case nil = substitutions.index(forKey: .summary)
        {
            substitutions[.summary]     = Element[.p]
            {
                "No overview available."
            }
        }
        for reference:Int in references 
        {
            substitutions[.card(.symbol(reference))] = articles[reference].summary
        }
        return Self.page(title: symbol.title, 
            substitutions: substitutions, 
            filter: filter, 
            dynamic: dynamic)
    }
    private static 
    func page(title:String, substitutions:[Anchor: HTML.Element<Anchor>], filter:[Package.ID], dynamic:HTML.Element<Anchor>) -> Resource
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
                Element[.script]
                {
                    // package name is alphanumeric, we should enforce this in 
                    // `Package.ID`, otherwise this could be a security hole
                    let source:String = 
                    """
                    includedPackages = [\(filter.map { "'\($0.name)'" }.joined(separator: ","))];
                    """
                    Element.text(escaped: source)
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
                        Element.anchor(id: .navigator)
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
                            Element[.article]
                            {
                                ["upper-container-left"]
                            }
                            content: 
                            {
                                Element.anchor(id: .introduction)
                                Element.anchor(id: .platforms)
                                Element.anchor(id: .declaration)
                                Element.anchor(id: .discussion)
                            }
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
        return .html(utf8: document.template(of: [UInt8].self).apply(substitutions).joined(), version: nil)
    }
    
    private 
    func render<S>(list types:S, heading:String) -> HTML.Element<Anchor>?
        where S:Sequence, S.Element == (index:Int, conditions:[SwiftLanguage.Constraint<Symbol.ID>])
    {
        typealias Element = HTML.Element<Anchor>
        // we will discard all errors from dynamic rendering
        var renderer:ArticleRenderer = .init(biome: self)
        let list:[Element] = types.map 
        {
            (item:(index:Int, conditions:[SwiftLanguage.Constraint<Symbol.ID>])) in 
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
                        (self.symbols[item.index].path.description, as: HTML.Href.self)
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
    func render<S>(topics:S, heading:String, articles:[Article], references:inout Set<Int>) -> HTML.Element<Anchor>?
        where S:Sequence, S.Element == (heading:Topic, indices:[Int])
    {
        typealias Element = HTML.Element<Anchor>
        let topics:[Element] = topics.map
        {
            (topic:(heading:Topic, indices:[Int])) in 
            let cards:[Element] = topic.indices.map
            {
                references.insert(self.symbols[$0].commentOrigin ?? $0)
                return articles[$0].card
            } 
            return Element[.div]
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
                    cards
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
    
    static 
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
    static 
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
    func render<ID>(code:[SwiftLanguage.Lexeme<Symbol.ID>], anchors:ID.Type = ID.self) -> [HTML.Element<ID>] 
    {
        code.map
        {
            Self.render(lexeme: $0, anchors: ID.self)
        }
    }
    static 
    func render<ID>(lexeme:SwiftLanguage.Lexeme<Symbol.ID>, anchors:ID.Type = ID.self) -> HTML.Element<ID>
    {
        switch lexeme
        {
        case .code(let text, class: let classification):
            let css:String
            switch classification 
            {
            case .punctuation: 
                return HTML.Element<ID>.text(escaping: text)
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
            return HTML.Element<ID>.span(text)
            {
                [css]
            }
        case .comment(let text, documentation: _):
            return HTML.Element<ID>.span(text)
            {
                ["syntax-comment"]
            } 
        case .invalid(let text):
            return HTML.Element<ID>.span(text)
            {
                ["syntax-invalid"]
            } 
        case .newlines(let count):
            return HTML.Element<ID>.span(String.init(repeating: "\n", count: count))
            {
                ["syntax-newline"]
            } 
        case .spaces(let count):
            return HTML.Element<ID>.text(escaped: String.init(repeating: " ", count: count)) 
        }
    }
}
