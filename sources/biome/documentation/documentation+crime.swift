import Resource
import StructuredDocument
import HTML

extension Documentation 
{
    typealias Element = HTML.Element<Anchor>
    
    @frozen public 
    enum Anchor:Hashable, Sendable
    {
        case symbol(Int)
        
        case title 
        case constants 
        
        case navigator
        case introduction
        case summary
        case platforms
        case declaration
        case discussion
        
        case dynamic
    }
    
    private 
    func substitutions(title:String, filter:[Biome.Package.ID]) -> [Anchor: Element] 
    {
        [
            .title:     Element[.title] 
            {
                title
            },
            .constants: Element[.script]
            {
                // package name is alphanumeric, we should enforce this in 
                // `Package.ID`, otherwise this could be a security hole
                let source:String = 
                """
                includedPackages = [\(filter.map { "'\($0.name)'" }.joined(separator: ","))];
                """
                Element.text(escaped: source)
            }
        ]
    }
    private 
    func substitutions<S>(title:String, comment:Comment, summaries:S, filter:[Biome.Package.ID]) -> [Anchor: Element] 
        where S:Sequence, S.Element == Int
    {
        var substitutions:[Anchor: Element] = self.substitutions(title: title, filter: filter)
        if let summary:Element = comment.summary
        {
            substitutions[.summary] = summary
        }
        if let discussion:Element = comment.discussion
        {
            substitutions[.discussion] = discussion
        }
        for origin:Int in summaries 
        {
            substitutions[.symbol(origin)] = self.symbols[origin].summary
        }
        return substitutions
    }
    
    func page(article index:Int, filter:[Biome.Package.ID]) -> Resource
    {
        let article:Article = self.articles[index]
        var substitutions:[Anchor: Element] = self.substitutions(title: article.title, filter: filter)
        substitutions[.discussion] = Element.bytes(utf8: [UInt8].init(article.content.apply([:] as [Documentation.Index: ArticleElement]).joined()))
        return .html(utf8: self.template.apply(substitutions).joined(), version: nil)
    }
    func page(package index:Int, filter:[Biome.Package.ID]) -> Resource
    {
        let package:Biome.Package = self.biome.packages[index]
        var substitutions:[Anchor: Element] = self.substitutions(
            title: package.name, 
            comment: .init(), 
            summaries: [], 
            filter: filter)
        
        substitutions[.navigator]       = Self.navigator(for: package)
        substitutions[.introduction]    = Self.introduction(for: package)
        substitutions[.dynamic]         = Element[.div]
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
                    for module:Int in package.modules
                    {
                        Element[.li]
                        {
                            Element[.code]
                            {
                                ["signature"]
                            }
                            content: 
                            {
                                self.item(module: module)
                            }
                        }
                    }
                }
            }
        }
        return .html(utf8: self.template.apply(substitutions).joined(), version: nil)
    }
    func page(module index:Int, filter:[Biome.Package.ID]) -> Resource
    {
        let module:Biome.Module     = self.biome.modules[index]
        
        let groups:[Bool: [Int]]    = self.biome.partition(symbols: module.toplevel)
        let comments:Set<Int>       = .init(self.biome.comments(backing: module.toplevel))
        
        var substitutions:[Anchor: Element] = self.substitutions(
            title: module.title, 
            comment: self.modules[index], 
            summaries: comments, 
            filter: filter)
        
        substitutions[.navigator]       = Self.navigator(for: module)
        substitutions[.introduction]    = self.introduction(for: module)
        substitutions[.declaration]     = Self.declaration(for: module)
        substitutions[.dynamic]         = Element[.div]
        {
            ["lower-container"]
        }
        content:
        {
            self.topics(self.biome.organize(symbols: groups[false, default: []], in: nil), heading: "Members")
            self.topics(self.biome.organize(symbols: groups[true,  default: []], in: nil), heading: "Removed Members")
        }
            
        return .html(utf8: self.template.apply(substitutions).joined(), version: nil)
    }
    func page(witness:Int, victim:Int?, filter:[Biome.Package.ID]) -> Resource
    {
        let symbol:Biome.Symbol     = self.biome.symbols[witness]
        
        let groups:[Bool: [Int]]    = symbol.relationships.members.map(self.biome.partition(symbols:)) ?? [:]
        var comments:Set<Int>       = symbol.relationships.members.map(self.biome.comments(backing:)).map(Set.init(_:)) ?? []
        let dynamic:Element         = Element[.div]
        {
            ["lower-container"]
        }
        content:
        {
            if case .protocol(let abstract) = symbol.relationships 
            {
                self.list(types: abstract.downstream.map { ($0, []) }, heading: "Refinements")
                
                self.topics(self.biome.organize(symbols: abstract.requirements, in: witness), heading: "Requirements")
                let _:Void = comments.formUnion(self.biome.comments(backing: abstract.requirements))
            }
            
            self.topics(self.biome.organize(symbols: groups[false, default: []], in: witness), heading: "Members")
            
            switch symbol.relationships 
            {
            case .protocol(let abstract):
                self.list(types: abstract.upstream.map{ ($0, []) },    heading: "Implies")
                self.list(types: abstract.conformers,                  heading: "Conforming Types")
            case .class(let concrete, subclasses: let subclasses, superclass: _):
                self.list(types: subclasses.map { ($0, []) },          heading: "Subclasses")
                self.list(types: concrete.upstream,                    heading: "Conforms To")
            case .enum(let concrete), .struct(let concrete), .actor(let concrete):
                self.list(types: concrete.upstream,                    heading: "Conforms To")
            default: 
                let _:Void = ()
            }
            self.topics(self.biome.organize(symbols: groups[true, default: []], in: witness), heading: "Removed Members")
        }
        var substitutions:[Anchor: Element] = self.substitutions(
            title: symbol.title, 
            comment: self.symbols[witness], 
            summaries: comments, 
            filter: filter)
        substitutions[.navigator]       = self.navigator(for: symbol, in: victim)
        substitutions[.introduction]    = self.introduction(for: symbol, witnessing: victim)
        substitutions[.declaration]     = self.declaration(for: symbol)
        substitutions[.platforms]       = Self.platforms(availability: symbol.platforms)
        if  let origin:Int = symbol.commentOrigin
        {
            substitutions[.summary]     = self.symbols[origin].summary
            substitutions[.discussion]  = self.symbols[origin].discussion
        }
        if case nil = substitutions.index(forKey: .summary)
        {
            substitutions[.summary]     = Element[.p]
            {
                "No overview available."
            }
        }
        substitutions[.dynamic]         = dynamic
        return .html(utf8: self.template.apply(substitutions).joined(), version: nil)
    }
    
    private static 
    func navigator(for package:Biome.Package) -> Element
    {
        Element[.ol] 
        {
            ["breadcrumbs-container"]
        }
        content:
        {
            Element[.li] 
            { 
                package.name 
            }
        }
    }
    private static 
    func navigator(for module:Biome.Module) -> Element
    {
        Element[.ol] 
        {
            ["breadcrumbs-container"]
        }
        content:
        {
            Element[.li] 
            { 
                module.title 
            }
        }
    }
    private 
    func navigator(for symbol:Biome.Symbol, in scope:Int?) -> Element
    {
        var breadcrumbs:[Element]   = [ Element[.li] { symbol.title } ]
        var next:Int?               = scope ?? symbol.parent
        while let index:Int         = next
        {
            breadcrumbs.append(Element[.li]
            {
                Element.link(self.biome.symbols[index].title, to: self.print(uri: self.uri(witness: index, victim: nil)), internal: true)
            })
            next = self.biome.symbols[index].parent
        }
        return Element[.ol] 
        {
            ["breadcrumbs-container"]
        }
        content:
        {
            breadcrumbs.reversed()
        }
    }
    
    private static 
    func introduction(for package:Biome.Package) -> Element
    {
        return Element[.section]
        {
            ["introduction"]
        }
        content:
        {
            Self.eyebrows(for: package)
            Element[.h1]
            {
                package.name
            }
            Element.anchor(id: .summary)
        }
    }
    private 
    func introduction(for module:Biome.Module) -> Element
    {
        Element[.section]
        {
            ["introduction"]
        }
        content:
        {
            self.eyebrows(for: module)
            Element[.h1]
            {
                module.title
            }
            Element.anchor(id: .summary)
        }
    }
    private 
    func introduction(for symbol:Biome.Symbol, witnessing victim:Int?) -> Element
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
                    self.constraints(symbol.extensionConstraints)
                }
            })
        }
        let availability:[Element] = Self.availability(symbol.availability)
        return Element[.section]
        {
            ["introduction"]
        }
        content:
        {
            self.eyebrows(for: symbol, witnessing: victim)
            Element[.h1]
            {
                symbol.title
            }
            Element.anchor(id: .summary)
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
    
    private static 
    func eyebrows(for package:Biome.Package) -> Element
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
    }
    private 
    func eyebrows(for module:Biome.Module) -> Element
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
                self.link(package: module.package)
            }
        }
    }
    private 
    func eyebrows(for symbol:Biome.Symbol, witnessing victim:Int?) -> Element
    {
        let electorate:Element?, 
            colony:Element
        if let module:Int   = symbol.module
        {
            colony          = self.link(module: module)
            if      let victim:Int      = victim, 
                    let namespace:Int   = self.biome.symbols[victim].namespace, namespace != module
            {
                electorate  = self.link(module: namespace)
            }
            else if let namespace:Int   =                     symbol.namespace, namespace != module 
            {
                electorate  = self.link(module: namespace)
            }
            else 
            {
                electorate  = nil
            }
        }
        else 
        {
            colony          = Element.span("(Mythical)") 
            electorate      = nil
        }
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
                if let electorate:Element = electorate
                {
                    Element[.span]
                    {
                        ["electorate"]
                    }
                    content:
                    {
                        electorate
                    }
                }
                colony 
            }
        }
    }
    
    private static 
    func declaration(for module:Biome.Module) -> Element
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
                    Element.highlight("import", .keywordText)
                    Element.highlight(" ", .text)
                    Element.highlight(module.id.string, .identifier)
                }
            }
        }
    }
    private 
    func declaration(for symbol:Biome.Symbol) -> Element
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
                    symbol.declaration.map(self.highlight(_:_:link:))
                }
            }
        }
    }
    
    private static
    func platforms(availability:[Biome.Domain: Biome.Availability]) -> Element?
    {
        var platforms:[Element] = []
        for platform:Biome.Domain in Biome.Domain.platforms 
        {
            if let availability:Biome.Availability = availability[platform]
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
                else if let version:Biome.Version = availability.introduced 
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

    private 
    func link(package:Int) -> Element
    {
        .link(self.biome.packages[package].name, to: self.print(uri: self.uri(package: package)), internal: true)
    }
    private 
    func link(module:Int) -> Element
    {
        .link(self.biome.modules[module].title, to: self.print(uri: self.uri(module: module)), internal: true)
    }
    
    private 
    func item(module:Int) -> Element
    {
        return Element[.a]
        {
            (self.print(uri: self.uri(module: module)), as: HTML.Href.self)
        }
        content: 
        {
            Element.highlight(self.biome.modules[module].id.string, .identifier)
        }
    }
    private 
    func item(symbol:Int) -> Element
    {
        self.item(symbol: symbol, displaying: symbol)
    }
    private 
    func item(symbol:Int, displaying display:Int) -> Element
    {
        return Element[.a]
        {
            (self.print(uri: self.uri(witness: symbol, victim: nil)), as: HTML.Href.self)
        }
        content: 
        {
            for component:String in self.biome.symbols[display].scope 
            {
                Element.highlight(component, .identifier)
                Element.highlight(".", .text)
            }
            Element.highlight(self.biome.symbols[display].title, .identifier)
        }
    }
    
    private 
    func list<S>(types:S, heading:String) -> Element?
        where S:Sequence, S.Element == (index:Int, conditions:[SwiftConstraint<Int>])
    {
        let list:[Element] = types.map 
        {
            (item:(index:Int, conditions:[SwiftConstraint<Int>])) in 
            Element[.li]
            {
                Element[.code]
                {
                    ["signature"]
                }
                content: 
                {
                    self.item(symbol: item.index)
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
                        self.constraints(item.conditions)
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
    func topics<S>(_ topics:S, heading:String) -> Element?
        where S:Sequence, S.Element == (heading:Topic, symbols:[(witness:Int, victim:Int?)])
    {
        let topics:[Element] = topics.map
        {
            (topic:(heading:Topic, symbols:[(witness:Int, victim:Int?)])) in 

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
                    for (witness, victim):(Int, Int?) in topic.symbols
                    {
                        self.card(witness: witness, victim: victim)
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
    
    private 
    func card(witness:Int, victim:Int?) -> Element
    {
        let symbol:Biome.Symbol     = self.biome.symbols[witness]
        let availability:[Element]  = Self.availability(symbol.availability)
        var relationships:[Element] = []
        if  case nil = victim, 
            let overridden:Int  =                   symbol.relationships.overrideOf, 
            let interface:Int   = self.biome.symbols[overridden].parent 
        {
            relationships.append(Element[.li]
            {
                Element[.p]
                {
                    if case .protocol = self.biome.symbols[interface].kind
                    {
                        "Refines requirement in "
                    } 
                    else 
                    {
                        "Overrides virtual member in "
                    } 
                    Element[.code]
                    {
                        self.item(symbol: overridden, displaying: interface)
                    }
                }
            })
        } 
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
                    (self.print(uri: self.uri(witness: witness, victim: victim)), as: HTML.Href.self)
                }
                content: 
                {
                    symbol.signature.content.map(Element.highlight(_:_:))
                }
            }
            
            Element.anchor(id: .symbol(symbol.commentOrigin ?? witness))
            
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
    
    private static 
    func availability(_ availability:(unconditional:Biome.UnconditionalAvailability?, swift:Biome.SwiftAvailability?)) -> [Element]
    {
        var availabilities:[Element] = []
        if let availability:Biome.UnconditionalAvailability = availability.unconditional
        {
            if availability.unavailable 
            {
                availabilities.append(Self.availability("Unavailable"))
            }
            else if availability.deprecated 
            {
                availabilities.append(Self.availability("Deprecated"))
            }
        }
        if let availability:Biome.SwiftAvailability = availability.swift
        {
            if let version:Biome.Version = availability.obsoleted 
            {
                availabilities.append(Self.availability("Obsolete", since: ("Swift", version)))
            } 
            else if let version:Biome.Version = availability.deprecated 
            {
                availabilities.append(Self.availability("Deprecated", since: ("Swift", version)))
            }
            else if let version:Biome.Version = availability.introduced
            {
                availabilities.append(Self.availability("Available", since: ("Swift", version)))
            }
        }
        return availabilities
    }
    private static 
    func availability(_ adjective:String, since:(domain:String, version:Biome.Version)? = nil) -> Element
    {
        return Element[.li]
        {
            Element[.p]
            {
                Element[.strong]
                {
                    adjective
                }
                if let (domain, version):(String, Biome.Version) = since 
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
    
    private 
    func constraints(_ constraints:[SwiftConstraint<Int>]) -> [Element] 
    {
        guard let ultimate:SwiftConstraint<Int> = constraints.last 
        else 
        {
            fatalError("cannot call \(#function) with empty constraints array")
        }
        guard let penultimate:SwiftConstraint<Int> = constraints.dropLast().last
        else 
        {
            return self.constraint(ultimate)
        }
        var fragments:[Element]
        if constraints.count < 3 
        {
            fragments =                  self.constraint(penultimate)
            fragments.append(.text(escaped: " and "))
            fragments.append(contentsOf: self.constraint(ultimate))
        }
        else 
        {
            fragments = []
            for constraint:SwiftConstraint<Int> in constraints.dropLast(2)
            {
                fragments.append(contentsOf: self.constraint(constraint))
                fragments.append(.text(escaped: ", "))
            }
            fragments.append(contentsOf: self.constraint(penultimate))
            fragments.append(.text(escaped: ", and "))
            fragments.append(contentsOf: self.constraint(ultimate))
        }
        return fragments
    }
    private 
    func constraint(_ constraint:SwiftConstraint<Int>) -> [Element] 
    {
        let prose:String
        switch constraint.verb
        {
        case .subclasses: 
            prose   = " inherits from "
        case .implements:
            prose   = " conforms to "
        case .is:
            prose   = " is "
        }
        let subject:Element = Element[.code]
        {
            Element.highlight(constraint.subject, .type)
        }
        let object:Element = Element[.code]
        {
            self.highlight(constraint.object, .type, link: constraint.link)
        }
        return [subject, Element.text(escaped: prose), object]
    }

    private 
    func highlight(_ text:String, _ highlight:SwiftHighlight, link:Int?) -> Element
    {
        return link.map { self.highlight(text, highlight, link: $0) } ?? .highlight(text, highlight)
    }
    private 
    func highlight(_ text:String, _ highlight:SwiftHighlight, link index:Int) -> Element
    {
        .link(text, to: self.print(uri: self.uri(witness: index, victim: nil)), internal: true)
        {
            ["syntax-type"] 
        }
    }
}

extension DocumentElement where Domain == HTML 
{
    static 
    func highlight(_ text:String, _ highlight:SwiftHighlight) -> Self
    {
        let css:[String]
        switch highlight
        {
        case .text: 
            return .text(escaping: text)
        case .type:
            css = ["syntax-type"]
        case .identifier:
            css = ["syntax-identifier"]
        case .generic:
            css = ["syntax-generic"]
        case .argument:
            css = ["syntax-parameter-label"]
        case .parameter:
            css = ["syntax-parameter-name"]
        case .directive, .attribute, .keywordText:
            css = ["syntax-keyword"]
        case .keywordIdentifier:
            css = ["syntax-keyword", "syntax-keyword-identifier"]
        case .pseudo:
            css = ["syntax-pseudo-identifier"]
        case .number, .string:
            css = ["syntax-literal"]
        case .interpolation:
            css = ["syntax-interpolation-anchor"]
        case .keywordDirective:
            css = ["syntax-macro"]
        case .newlines:
            css = ["syntax-newline"]
        case .comment, .documentationComment:
            css = ["syntax-comment"]
        case .invalid:
            css = ["syntax-invalid"]
        }
        return .span(text) { css }
    }
}
