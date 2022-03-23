import Resource
import StructuredDocument
import HTML

extension Documentation 
{
    typealias Element = HTML.Element<Anchor>
    typealias StaticElement = HTML.Element<Never>
    
    @frozen public 
    enum Anchor:Hashable, Sendable
    {
        case symbol(Int)
        
        case title 
        case constants 
        
        case navigator
        case kind
        case metropole 
        case colony 
        case summary
        case relationships 
        case availability 
        
        case platforms
        case declaration
        
        case _introduction
        case discussion
        
        case dynamic
    }
    
    private 
    func present(reference resolved:ResolvedLink) -> StaticElement
    {
        let components:[(text:String, uri:URI)], 
            tail:(text:String, uri:URI)

        switch resolved
        {
        case .article(let article): 
            return StaticElement.link(self.articles[article].title, 
                to: self.print(uri: self.uri(article: article)), 
                internal: true)
        
        case .module(let module):
            components  = []
            tail        = 
            (
                self.biome.modules[module].title,
                self.biome.uri(module: module)
            )
        case .symbol(let witness, victim: let victim):
            var reversed:[(text:String, uri:URI)] = []
            var next:Int?       = victim ?? self.biome.symbols[witness].parent
            while let index:Int = next
            {
                reversed.append(
                    (
                        self.biome.symbols[index].title, 
                        self.biome.uri(witness: index, victim: nil, routing: self.routing)
                    ))
                next    = self.biome.symbols[index].parent
            }
            components  = reversed.reversed()
            tail        = 
            (
                self.biome.symbols[witness].title, 
                self.biome.uri(witness: witness, victim: victim, routing: self.routing)
            )
        }
        return StaticElement[.code]
        {
            // unlike in breadcrumbs, we print the dot separators explicitly 
            // so they look normal when highlighted and copy-pasted 
            for (text, uri):(String, URI) in components 
            {
                StaticElement.link(text, to: self.biome.format(uri:       uri, routing: self.routing), internal: true)
                StaticElement.text(escaped: ".")
            }
            StaticElement.link(tail.text, to: self.biome.format(uri: tail.uri, routing: self.routing), internal: true)
        }
    }
    private 
    func fill(template:DocumentTemplate<ResolvedLink, [UInt8]>) -> [UInt8] 
    {
        let presented:[ResolvedLink: StaticElement] = .init(uniqueKeysWithValues: 
            Set.init(template.anchors.map(\.id)).map 
        {
            ($0, self.present(reference: $0))
        })
        let fragments:[ArraySlice<UInt8>] = template.apply(presented)
        return [UInt8].init(fragments.joined())
    }
    private 
    func fill(template:DocumentTemplate<ResolvedLink, [UInt8]>) -> Element
    {
        .bytes(utf8: self.fill(template: template))
    }
    
    private static 
    func constants(filter:[Biome.Package.ID]) -> String
    {
        // package name is alphanumeric, we should enforce this in 
        // `Package.ID`, otherwise this could be a security hole
        """
        includedPackages = [\(filter.map { "'\($0.name)'" }.joined(separator: ","))];
        """
    }

    func substitutions(title:String, content:ArticleContent<ResolvedLink>) 
        -> [Anchor: [UInt8]] 
    {
        var substitutions:[Anchor: [UInt8]] = 
        [
            .title: [UInt8].init(title.utf8)
        ]
        substitutions[._introduction]   = content.summary.map(self.fill(template:))
        substitutions[.discussion]      = content.discussion.map(self.fill(template:))
        return substitutions
    } 
    func substitutions(for article:Article<ResolvedLink>, filter:[Biome.Package.ID]) 
        -> [Anchor: Element] 
    {
        var substitutions:[Anchor: Element] = 
        [
            .title:     .text(escaping: article.title), 
            .constants: .text(escaped: Self.constants(filter: filter)),
            .navigator:  self.navigator(for: article),
            
            .kind:      .text(escaped: "Module"),
            .metropole:  self.link(package: self.biome.modules[article.context.namespace].package),
        ]
        substitutions[._introduction]   = article.content.summary.map(self.fill(template:))
        substitutions[.discussion]      = article.content.discussion.map(self.fill(template:))
        return substitutions
    } 
    
    private 
    func substitutions(for package:Biome.Package, dynamic:Element, filter:[Biome.Package.ID]) 
        -> [Anchor: Element] 
    {
        var substitutions:[Anchor: Element] = 
        [
            .title:     .text(escaping: package.name), 
            .constants: .text(escaped: Self.constants(filter: filter))
        ]
        
        substitutions[.navigator] = Self.navigator(for: package)
        
        if case .swift = package.id 
        {
            substitutions[.kind] = .text(escaped: "Standard Library")
        }
        else 
        {
            substitutions[.kind] = .text(escaped: "Package")
        }
        substitutions[.dynamic] = dynamic
        return substitutions
    }
    private 
    func substitutions(for module:Biome.Module, 
        article:ArticleContent<ResolvedLink>, 
        dynamic:Element, 
        cards:Set<Int>, 
        filter:[Biome.Package.ID]) 
        -> [Anchor: Element] 
    {
        var substitutions:[Anchor: Element] = 
        [
            .title:        .text(escaping: module.title), 
            .constants:    .text(escaped: Self.constants(filter: filter)),
            
            .navigator:     Self.navigator(for: module),
            
            .kind:         .text(escaped: "Module"),
            .metropole:     self.link(package: module.package),
            .declaration:   Self.declaration(for: module),
            .dynamic:       dynamic,
        ]
        
        substitutions[.summary]     = article.summary.map(self.fill(template:))
        substitutions[.discussion]  = article.discussion.map(self.fill(template:))
        
        for origin:Int in cards 
        {
            substitutions[.symbol(origin)] = self.symbols[origin].summary.map(self.fill(template:))
        }
        
        return substitutions
    }
    private 
    func substitutions(for symbol:Biome.Symbol, witnessing victim:Int?, 
        article:ArticleContent<ResolvedLink>, 
        dynamic:Element, 
        cards:Set<Int>, 
        filter:[Biome.Package.ID]) 
        -> [Anchor: Element] 
    {
        var substitutions:[Anchor: Element] = 
        [
            .title:        .text(escaping: symbol.title), 
            .constants:    .text(escaped: Self.constants(filter: filter)),
            
            .navigator:     self.navigator(for: symbol, in: victim),
            
            .kind:         .text(escaping: symbol.kind.title),
            .declaration:   self.declaration(for: symbol),
            .dynamic:       dynamic,
        ]
        
        substitutions[.platforms]   = Self.platforms(availability: symbol.platforms)
        substitutions[.summary]     = article.summary.map(self.fill(template:))
        substitutions[.discussion]  = article.discussion.map(self.fill(template:))
        
        if case nil = substitutions.index(forKey: .summary)
        {
            substitutions[.summary]     = Element[.p]
            {
                "No overview available."
            }
        }
        for origin:Int in cards 
        {
            substitutions[.symbol(origin)] = self.symbols[origin].summary.map(self.fill(template:))
        }
        
        let metropole:Element?
        if let module:Int   = symbol.module
        {
            if      let victim:Int      = victim, 
                    let namespace:Int   = self.biome.symbols[victim].namespace, namespace != module
            {
                metropole   = self.link(module: namespace)
            }
            else if let namespace:Int   =                     symbol.namespace, namespace != module 
            {
                metropole   = self.link(module: namespace)
            }
            else 
            {
                metropole   = nil
            }
            substitutions[.colony] = self.link(module: module)
        }
        else 
        {
            metropole = nil
            substitutions[.colony] = Element.span("(Mythical)") 
        }
        if let metropole:Element = metropole  
        {
            substitutions[.metropole] = Element[.span]
            {
                ["metropole"]
            }
            content:
            {
                metropole
            }
        }
        
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
        
        if !relationships.isEmpty 
        {
            substitutions[.relationships] = Element[.ul]
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
            substitutions[.availability] = Element[.ul]
            {
                ["availability-list"]
            }
            content: 
            {
                availability
            }
        }
        
        return substitutions
    }
    
    func page(article index:Int, filter:[Biome.Package.ID]) -> Resource
    {
        let substitutions:[Anchor: Element] = self.substitutions(for: self.articles[index], filter: filter)
        return .html(utf8: self.template.apply(substitutions).joined(), version: nil)
    }
    func page(package index:Int, filter:[Biome.Package.ID]) -> Resource
    {
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
                    for module:Int in self.biome.packages[index].modules
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
        let substitutions:[Anchor: Element] = self.substitutions(for: self.biome.packages[index], dynamic: dynamic, filter: filter)
        return .html(utf8: self.template.apply(substitutions).joined(), version: nil)
    }
    func page(module index:Int, filter:[Biome.Package.ID]) -> Resource
    {
        let module:Biome.Module = self.biome.modules[index]
        
        let groups:[Bool: [Int]]    = self.biome.partition(symbols: module.toplevel)
        let cards:Set<Int>          = .init(self.biome.comments(backing: module.toplevel))
        let dynamic:Element         = Element[.div]
        {
            ["lower-container"]
        }
        content:
        {
            self.topics(self.biome.organize(symbols: groups[false, default: []], in: nil), heading: "Members")
            self.topics(self.biome.organize(symbols: groups[true,  default: []], in: nil), heading: "Removed Members")
        }
        
        let substitutions:[Anchor: Element] = self.substitutions(for: module, 
            article: self.modules[index], 
            dynamic: dynamic, 
            cards:   cards,
            filter:  filter)
            
        return .html(utf8: self.template.apply(substitutions).joined(), version: nil)
    }
    func page(witness:Int, victim:Int?, filter:[Biome.Package.ID]) -> Resource
    {
        let symbol:Biome.Symbol     = self.biome.symbols[witness]
        
        let groups:[Bool: [Int]]    = symbol.relationships.members.map(self.biome.partition(symbols:)) ?? [:]
        var cards:Set<Int>          = symbol.relationships.members.map(self.biome.comments(backing:)).map(Set.init(_:)) ?? []
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
                let _:Void = cards.formUnion(self.biome.comments(backing: abstract.requirements))
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
        
        let substitutions:[Anchor: Element] = self.substitutions(for: symbol, witnessing: victim,
            article: self.symbols[symbol.commentOrigin ?? witness], 
            dynamic: dynamic, 
            cards:   cards,
            filter:  filter)
        
        return .html(utf8: self.template.apply(substitutions).joined(), version: nil)
    }
    
    private 
    func navigator(for article:Article<ResolvedLink>) -> Element
    {
        Element[.ol] 
        {
            ["breadcrumbs-container"]
        }
        content:
        {
            Element[.li] 
            { 
                Element.link(self.biome.modules[article.context.namespace].title, 
                    to: self.print(uri: self.uri(module: article.context.namespace)), internal: true)
            }
        }
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
    func declaration(for module:Biome.Module) -> Element
    {
        Element[.section]
        {
            ["declaration"]
        }
        content:
        {
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
