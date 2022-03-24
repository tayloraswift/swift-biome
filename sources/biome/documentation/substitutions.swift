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

    func substitutions(title:String, content:Article<ResolvedLink>.Content) 
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
    func substitutions(article index:Int, filter:[Biome.Package.ID]) -> [Anchor: Element] 
    {
        let article:Article<ResolvedLink> = self.articles[index]
        let module:Biome.Module = self.biome.modules[article.trunk]
        var substitutions:[Anchor: Element] = 
        [
            .title:     .text(escaping: article.title), 
            .constants: .text(escaped: Self.constants(filter: filter)),
            .kind:      .text(escaped: "Article"),
            .metropole:  self.link(package: module.package),
            .navigator:  Element[.ol] 
            {
                ["breadcrumbs-container"]
            }
            content:
            {
                Element[.li] 
                { 
                    Element.link(module.title, to: self.print(uri: self.uri(module: article.trunk)), 
                        internal: true)
                }
            }, 
        ]
        substitutions[._introduction]   =  article.content.summary.map(self.fill(template:))
        substitutions[.discussion]      =  article.content.discussion.map(self.fill(template:))
        return substitutions
    } 
    func substitutions(package index:Int, filter:[Biome.Package.ID]) -> [Anchor: Element] 
    {
        let package:Biome.Package = self.biome.packages[index]
        var substitutions:[Anchor: Element] = 
        [
            .title:     .text(escaping: package.name), 
            .constants: .text(escaped: Self.constants(filter: filter)), 
            .navigator: Element[.ol] 
            {
                ["breadcrumbs-container"]
            }
            content:
            {
                Element[.li] 
                { 
                    package.name 
                }
            }, 
            .dynamic:   Element[.div]
            {
                ["lower-container"]
            }
            content:
            {
                self.dynamicContent(package: index)
            },
        ]
        
        if case .swift = package.id 
        {
            substitutions[.kind] = .text(escaped: "Standard Library")
        }
        else 
        {
            substitutions[.kind] = .text(escaped: "Package")
        }
        return substitutions
    }
    func substitutions(module index:Int, filter:[Biome.Package.ID]) -> [Anchor: Element] 
    {
        let module:Biome.Module = self.biome.modules[index]
        let dynamic:(sections:[Element], cards:Set<Int>) = self.dynamicContent(module: index)
        var substitutions:[Anchor: Element] = 
        [
            .title:        .text(escaping: module.title), 
            .constants:    .text(escaped: Self.constants(filter: filter)),
            .navigator:    Element[.ol] 
            {
                ["breadcrumbs-container"]
            }
            content:
            {
                Element[.li] 
                { 
                    module.title 
                }
            },
            .kind:         .text(escaped: "Module"),
            .metropole:     self.link(package: module.package),
            .declaration:   Self.declaration(for: module),
            .dynamic:       Element[.div]
            {
                ["lower-container"]
            }
            content:
            {
                dynamic.sections
            },
        ]
        
        let article:Article<ResolvedLink>.Content = self.modules[index]
        substitutions[.summary]     = article.summary.map(self.fill(template:))
        substitutions[.discussion]  = article.discussion.map(self.fill(template:))
        
        for origin:Int in dynamic.cards 
        {
            substitutions[.symbol(origin)] = self.symbols[origin].summary.map(self.fill(template:))
        }
        
        return substitutions
    }
    func substitutions(witness:Int, victim:Int?, filter:[Biome.Package.ID]) -> [Anchor: Element] 
    {
        let symbol:Biome.Symbol = self.biome.symbols[witness]
        let dynamic:(sections:[Element], cards:Set<Int>) = self.dynamicContent(witness: witness)
        
        var substitutions:[Anchor: Element] = 
        [
            .title:        .text(escaping: symbol.title), 
            .constants:    .text(escaped: Self.constants(filter: filter)),
            
            .navigator:     self.navigator(for: symbol, in: victim),
            
            .kind:         .text(escaping: symbol.kind.title),
            .declaration:   self.declaration(for: symbol),
            .dynamic:       Element[.div]
            {
                ["lower-container"]
            }
            content:
            {
                dynamic.sections
            },
        ]
        
        substitutions[.platforms]   = Self.platforms(availability: symbol.platforms)
        
        if case nil = substitutions.index(forKey: .summary)
        {
            substitutions[.summary]     = Element[.p]
            {
                "No overview available."
            }
        }
        for origin:Int in dynamic.cards 
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
        
        let article:Article<ResolvedLink>.Content = self.symbols[symbol.commentOrigin ?? witness]
        substitutions[.summary]     = article.summary.map(self.fill(template:))
        substitutions[.discussion]  = article.discussion.map(self.fill(template:))
        
        return substitutions
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
    
    static 
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
