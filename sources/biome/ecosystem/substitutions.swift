import HTML

extension Ecosystem 
{
    func fill(trace:[Index], uris:[Ecosystem.Index: String]) -> HTML.Element<Never>
    {
        var crumbs:[HTML.Element<Never>] = []
            crumbs.reserveCapacity(2 * trace.count - 1)
        for crumb:Ecosystem.Index in trace.reversed()
        {
            if !crumbs.isEmpty 
            {
                crumbs.append(.text(escaped: "."))
            }
            let text:String 
            switch crumb 
            {
            case .article(let article): 
                text = self[article].name
            case .package(let package): 
                text = self[package].name
            case .module(let module): 
                text = self[module].name // not `title`!
            case .composite(let composite): 
                text = self[composite.base].name 
            }
            if let uri:String = uris[crumb] 
            {
                crumbs.append(.a(text) { ("href", uri) })
            }
            else 
            {
                crumbs.append(.text(escaping: text))
            }
        }
        return .code(crumbs)
    }
    
    private 
    func sort<Value>(_ segregated:[Module.Culture: Value]) 
        -> [(key:Module.Culture, value:Value)]
    {
        segregated.sorted 
        {
            switch ($0.key, $1.key)
            {
            case (_, .primary):
                return false 
            case (.primary, _): 
                return true 
            case (.accepted(let first), .accepted(let second)): 
                return self[first].name < self[second].name
            case (.accepted(_), .international(_)): 
                return true
            case (.international(_), .accepted(_)): 
                return false
            case (.international(let first), .international(let second)): 
                // sort packages by the order they were added, not by name 
                return  ( first.package, self[ first].name) < 
                        (second.package, self[second].name)
            }
        }
    }
    private 
    func sort(_ targets:[Symbol.Conditional]) -> [(target:Symbol.Conditional, host:Symbol.Index)]
    {
        targets.map 
        {
            (target:Symbol.Conditional) -> (target:Symbol.Conditional, host:Symbol.Index) in 
            (target: target, host: self[target.index].type ?? target.index)
        }
        .sorted 
        {
            self[$0.host].path.lexicographicallyPrecedes(self[$1.host].path)
        }
    }
    private 
    func sort(_ roles:Symbol.Roles?) -> [(target:Symbol.Index, host:Symbol.Index)]
    {
        switch roles 
        {
        case nil: 
            return []
        case .one(let target): 
            return [(target, self[target].type ?? target)]
        case .many(let targets):
            return targets.map 
            {
                (target:Symbol.Index) -> (target:Symbol.Index, host:Symbol.Index) in 
                (target: target, host: self[target].type ?? target)
            }
            .sorted 
            {
                self[$0.host].path.lexicographicallyPrecedes(self[$1.host].path)
            }
        }
    }
    private 
    func sort(_ cards:[Symbol.Card]) -> [Symbol.Card]
    {
        cards.sorted 
        {
            // this lexicographic ordering sorts by last path component first, 
            // and *then* by vending protocol (if applicable)
            let base:(Symbol, Symbol) = 
            (
                self[$0.composite.base], 
                self[$1.composite.base]
            )
            if  base.0.name < base.1.name 
            {
                return true 
            }
            else if base.0.name == base.1.name 
            {
                return base.0.path.prefix
                    .lexicographicallyPrecedes(base.1.path.prefix)
            }
            else 
            {
                return false 
            }
        }
    }
}
extension Ecosystem
{
    func generateExcerpt(for composite:Symbol.Composite, pins:[Package.Index: Version])
        -> DOM.Template<[Index], [UInt8]>?
    {
        let article:Article.Template<Link> = self.baseTemplate(composite, pins: pins)
        return article.summary.isEmpty ? nil : article.summary.map(self.expand(link:)) 
    }
    
    func generateCards(_ topics:Topics) -> DOM.Template<CardKey, [UInt8]>?
    {
        if topics.isEmpty 
        {
            return nil 
        }
        
        var sections:[HTML.Element<CardKey>] = []
        for heading:Topics.List in 
        [
            .refinements,
            .implementations,
            .restatements, 
            .overrides,
        ]
        {
            if let segregated:[Module.Culture: [Symbol.Conditional]] = topics.lists[heading]
            {
                sections.append(self.generateSection(segregated, heading: heading.rawValue))
            }
        }
        
        if !topics.requirements.isEmpty
        {
            let requirements:[Topics.Sublist: [Module.Culture: [Symbol.Card]]] = 
                topics.requirements.mapValues { [.primary: $0] }
            sections.append(self.generateSection(requirements, heading: "Requirements"))
        }
        if !topics.members.isEmpty
        {
            sections.append(self.generateSection(topics.members, heading: "Members"))
        }
        
        for heading:Topics.List in 
        [
            .conformers,
            .conformances,
            .subclasses,
            .implications,
        ]
        {
            if let list:[Module.Culture: [Symbol.Conditional]] = topics.lists[heading]
            {
                sections.append(self.generateSection(list, heading: heading.rawValue))
            }
        }
        
        if !topics.removed.isEmpty
        {
            sections.append(self.generateSection(topics.removed, 
                heading: "Removed Members"))
        }
        
        return sections.isEmpty ? nil : 
            .init(freezing: .div(sections) { ("class", "lower-container") })
    }
    
    private 
    func generateSection(_ segregated:[Module.Culture: [Symbol.Conditional]], 
        heading:String)
        -> HTML.Element<CardKey>
    {
        var elements:[HTML.Element<CardKey>] = []
            elements.reserveCapacity(2 * segregated.count + 1)
            elements.append(.h2(heading))
        for (culture, targets):(Module.Culture, [Symbol.Conditional]) in self.sort(segregated)
        {
            if let culture:HTML.Element<CardKey> = self.generateCultureHeading(culture)
            {
                elements.append(.h3(culture))
            }
            let items:[HTML.Element<CardKey>] = self.sort(targets).map 
            {
                let (target, host):(Symbol.Conditional, Symbol.Index) = $0
                let signature:HTML.Element<CardKey> = .a(.render(path: self[host].path))
                {
                    ("href", .anchor(.uri(.symbol(target.index))))
                    ("class", "signature")
                }
                if  let constraints:HTML.Element<CardKey> = .render(.text(escaped: "When"), 
                    constraints: target.conditions, 
                    transform: { .uri(.symbol($0)) }) 
                {
                    return .li([signature, constraints])
                }
                else 
                {
                    return .li(signature)
                }
            }
            
            elements.append(.ul(items: items))
        }
        return .section(elements) { ("class", "related") }
    }
    private 
    func generateSection(_ segregated:[Topics.Sublist: [Module.Culture: [Symbol.Card]]], 
        heading:String)
        -> HTML.Element<CardKey>
    {
        var elements:[HTML.Element<CardKey>] = [.h2(heading)]
        for sublist:Topics.Sublist in Topics.Sublist.allCases
        {
            if let segregated:[Module.Culture: [Symbol.Card]] = segregated[sublist]
            {
                elements.append(self.generateSubsection(segregated, heading: sublist.heading))
            }
        }
        return .section(elements) { ("class", "topics") }
    }
    private 
    func generateSubsection(_ segregated:[Module.Culture: [Symbol.Card]], 
        heading:String)
        -> HTML.Element<CardKey>
    {
        var elements:[HTML.Element<CardKey>] = []
            elements.reserveCapacity(2 * segregated.count + 1)
            elements.append(.h3(heading))
        for (culture, cards):(Module.Culture, [Symbol.Card]) in 
            self.sort(segregated)
        {
            if let culture:HTML.Element<CardKey> = self.generateCultureHeading(culture)
            {
                elements.append(.h4(culture))
            }
            let items:[HTML.Element<CardKey>] = self.sort(cards).map 
            {
                (card:Symbol.Card) in 
                
                let signature:HTML.Element<CardKey> = 
                    .a(.render(signature: card.declaration.signature))
                {
                    ("href", .anchor(.uri(.composite(card.composite))))
                    ("class", "signature")
                }
                return .li([signature, .anchor(.excerpt(card.composite))])
            }
            elements.append(.ul(items: items))
        }
        return .section(elements) 
    }
    
    private 
    func generateCultureHeading(_ culture:Module.Culture) -> HTML.Element<CardKey>?
    {
        switch culture 
        {
        case .primary: 
            return nil
        case .accepted(let culture), .international(let culture):
            return .a(String.init(self[culture].title)) 
            { 
                ("href", .anchor(.uri(.module(culture)))) 
            }
        }
    }
}
extension Ecosystem
{
    func generateFields(for composite:Symbol.Composite, 
        declaration:Symbol.Declaration, 
        facts:Symbol.Predicates) 
        -> [PageKey: DOM.Template<Index, [UInt8]>]
    {
        let base:Symbol = self[composite.base]
        var substitutions:[PageKey: HTML.Element<Index>] = 
        [
            .title:        .text(escaping: base.name), 
            .headline:     .h1(base.name), 
            .kind:         .text(escaping: base.color.title),
            .fragments:    .render(fragments: declaration.fragments, 
                transform: Index.symbol(_:)),
            
            .culture:       self.link(module: composite.culture),
            
            .constants:     Self.generateScript(filter: []),
            .breadcrumbs:   self.generateBreadcrumbs(for: composite),
        ]
        
        substitutions[.notes] = self.generateNotes(for: composite, 
            declaration: declaration, 
            facts: facts)
        
        substitutions[.platforms] = .render(
            availability: declaration.availability.platforms)
        substitutions[.availability] = .render(
            availability: 
        (
            declaration.availability.swift, 
            declaration.availability.general
        ))
        
        if composite.diacritic.host.module != composite.culture 
        {
            substitutions[.namespace] = 
                .span(self.link(module: composite.diacritic.host.module))
            {
                ("class", "namespace")
            }
        }
        if composite.base.module != composite.culture 
        {
            substitutions[.base] = 
                .span(self.link(module: composite.base.module))
            {
                ("class", "base")
            }
        }
        
        return substitutions.mapValues(DOM.Template<Index, [UInt8]>.init(freezing:))
    }
    
    private 
    func generateNotes(for composite:Symbol.Composite,
        declaration:Symbol.Declaration, 
        facts:Symbol.Predicates) 
        -> HTML.Element<Index>?
    {
        let base:Symbol = self[composite.base]
        
        var items:[HTML.Element<Index>] = []
        switch (base.shape, composite.host)
        {        
        case (.member(of: let interface)?, let host?):
            let subject:HTML.Element<Index> = 
                .highlight(escaped: "Self", .type, href: .symbol(host))
            let object:HTML.Element<Index> = 
                .highlight(self[interface].name, .type, href: .symbol(composite.base))
            let sentence:[HTML.Element<Index>] = 
            [
                .text(escaped: "Available because "),
                .code(subject),
                .text(escaped: " conforms to "),
                .code(object),
                .text(escaped: "."),
            ]
            items.append(.li(.p(sentence)))
        
        case (.member(of: _)?, nil): 
            guard case .callable(_) = base.color 
            else 
            {
                break 
            }
            for upstream:(target:Symbol.Index, host:Symbol.Index) in 
                self.sort(facts.roles)
            {
                let type:Symbol = self[upstream.host]
                let prose:String 
                switch type.color 
                {
                case .protocol: 
                    prose = "Implements requirement of "
                case .class: 
                    prose = "Overrides member of "
                default: 
                    continue 
                }
                let object:HTML.Element<Index> = 
                    .highlight(type.name, .type, href: .symbol(upstream.target))
                let sentence:[HTML.Element<Index>] = 
                [
                    .text(escaped: prose),
                    .code(object),
                    .text(escaped: "."),
                ]
                items.append(.li(.p(sentence)))
            } 
        
        case (.requirement(of: _)?, _):
            items.append(.li(.p("Required.") { ("class", "required") }))
            
            for requirement:(target:Symbol.Index, host:Symbol.Index) in 
                self.sort(facts.roles)
            {
                let object:HTML.Element<Index> = 
                    .highlight(self[requirement.host].name, .type, 
                        href: .symbol(requirement.target))
                let sentence:[HTML.Element<Index>] = 
                [
                    .text(escaped: "Restates requirement of "),
                    .code(object),
                    .text(escaped: "."),
                ]
                items.append(.li(.p(sentence)))
            }
        case (nil, _): 
            break
        }
        
        if let constraints:HTML.Element<Index> = .render(.text(escaped: "Available when"), 
            constraints: declaration.extensionConstraints, 
            transform: Index.symbol(_:)) 
        {
            items.append(.li(constraints))
        }
        
        return items.isEmpty ? nil : .ul(items: items) { ("class", "notes") }
    }
    
    private 
    func generateBreadcrumbs(for composite:Symbol.Composite) -> HTML.Element<Index>
    {
        let base:Symbol = self[composite.base]
        
        var crumbs:[HTML.Element<Index>] = [.li(base.name)]
        var next:Symbol.Index? = composite.host ?? base.shape?.index
        while let index:Symbol.Index = next
        {
            let current:Symbol = self[index]
            let crumb:HTML.Element<Index> = .a(.highlight(current.name, .type))
            {
                ("href", .anchor(.symbol(index)))
            }
            crumbs.append(.li(crumb))
            next = current.shape?.index
        }
        crumbs.reverse()
        return .ol(items: crumbs) { ("class", "breadcrumbs-container") }
    }
    
    private static 
    func generateScript(filter:[Package.ID]) -> HTML.Element<Index>
    {
        // package name is alphanumeric, we should enforce this in 
        // `Package.ID`, otherwise this could be a security hole
        let source:String =
        """
        includedPackages = [\(filter.map { "'\($0.string)'" }.joined(separator: ","))];
        """
        return .text(escaped: source)
    }

    private 
    func link(package:Package.Index) -> HTML.Element<Index>
    {
        .a(self[package].name) { ("href", .anchor(.package(package))) }
    }
    private 
    func link(module:Module.Index) -> HTML.Element<Index>
    {
        .a(String.init(self[module].title)) { ("href", .anchor(.module(module))) }
    }
} 


/*  
public 
func substitutions(for article:Article.Rendered<ResolvedLink>) -> [Anchor: Element] 
{
    var substitutions:[Anchor: Element] = 
    [
        .title: .text(escaping: article.title), 
    ]
    substitutions[.headline]        = article.headline
    substitutions[._introduction]   = article.content.summary.map(self.fill(template:))
    substitutions[.discussion]      = article.content.discussion.map(self.fill(template:))
    return substitutions
} 
func substitutions(article index:Int, filter:[Package.ID]) -> [Anchor: Element] 
{
    let expatriate:Expatriate<Article.Rendered<ResolvedLink>> = self.articles[index]
    let article:Article.Rendered<ResolvedLink> = expatriate.conquistador
    let module:Module = self.biome.modules[expatriate.trunk]
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
                Element.link(module.title, to: self.format(uri: self.uri(module: expatriate.trunk)), 
                    internal: true)
            }
        }, 
    ]
    substitutions[.headline]        = article.headline
    substitutions[._introduction]   = article.content.summary.map(self.fill(template:))
    substitutions[.discussion]      = article.content.discussion.map(self.fill(template:))
    return substitutions
} 
func substitutions(package index:Int, filter:[Package.ID]) -> [Anchor: Element] 
{
    let package:Package = self.biome.packages[index]
    var substitutions:[Anchor: Element] = 
    [
        .title:     .text(escaping: package.name), 
        .headline:  Element[.h1] { package.name }, 
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
    
    if case .swift = package.id.kind 
    {
        substitutions[.kind] = .text(escaped: "Standard Library")
    }
    else 
    {
        substitutions[.kind] = .text(escaped: "Package")
    }
    return substitutions
}
func substitutions(module index:Int, filter:[Package.ID]) -> [Anchor: Element] 
{
    let module:Module = self.biome.modules[index]
    let dynamic:(sections:[Element], cards:Set<Int>) = self.dynamicContent(module: index)
    var substitutions:[Anchor: Element] = 
    [
        .title:        .text(escaping: module.title), 
        .headline:     Element[.h1] { module.title }, 
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
        .fragments:     Self.fragments(for: module),
        .dynamic:       Element[.div]
        {
            ["lower-container"]
        }
        content:
        {
            dynamic.sections
        },
    ]
    
    let article:Article.Rendered<ResolvedLink>.Content = self.modules[index]
    substitutions[.summary]     = article.summary.map(self.fill(template:))
    substitutions[.discussion]  = article.discussion.map(self.fill(template:))
    
    for origin:Int in dynamic.cards 
    {
        substitutions[.reference(.symbol(origin, victim: nil))] = 
            self.symbols[origin].summary.map(self.fill(template:))
    }
    
    return substitutions
}
*/
