import HTML

extension Ecosystem
{
    func renderFields(for index:Module.Index) 
        -> [Page.Key: DOM.Template<Index, [UInt8]>]
    {
        let module:Module = self[index]
        let title:String = .init(module.title)
        let substitutions:[Page.Key: HTML.Element<Index>] = 
        [
            .title:        .text(escaping: title), 
            .headline:     .h1(title), 
            .kind:         .text(escaped: "Module"),
            .fragments:    .render(fragments: module.fragments) { (_:Never) -> Index in },
            .culture:       self.link(package: index.package),
        ]
        return substitutions.mapValues(DOM.Template<Index, [UInt8]>.init(freezing:))
    }
    func renderFields(for index:Article.Index, headline:Article.Headline) 
        -> [Page.Key: DOM.Template<Index, [UInt8]>]
    {
        let substitutions:[Page.Key: HTML.Element<Index>] = 
        [
            .title:        .text(escaping: headline.plain), 
            .headline:     .h1(.bytes(utf8: headline.formatted)), 
            .kind:         .text(escaped: "Article"),
            .culture:       self.link(module: index.module),
        ]
        return substitutions.mapValues(DOM.Template<Index, [UInt8]>.init(freezing:))
    }
    func renderFields(for composite:Symbol.Composite, 
        declaration:Symbol.Declaration, 
        facts:Symbol.Predicates) 
        -> [Page.Key: DOM.Template<Index, [UInt8]>]
    {
        let base:Symbol = self[composite.base]
        var substitutions:[Page.Key: HTML.Element<Index>] = 
        [
            .title:        .text(escaping: base.name), 
            .headline:     .h1(base.name), 
            .kind:         .text(escaping: base.color.title),
            .fragments:    .render(fragments: declaration.fragments, 
                transform: Index.symbol(_:)),
            
            .culture:       self.link(module: composite.culture),
            
            .breadcrumbs:   self.renderBreadcrumbs(for: composite),
        ]
        
        substitutions[.notes] = self.renderNotes(for: composite, 
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
    func renderNotes(for composite:Symbol.Composite,
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
    func renderBreadcrumbs(for composite:Symbol.Composite) -> HTML.Element<Index>
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
        return .ol(items: crumbs) 
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

extension Ecosystem 
{
    // this takes separate ``Version`` and ``Package`` arguments instead of a 
    // combined `Package.Pinned` argument to avoid confusion
    func render(availableVersions:[Version], currentVersion:Version, of package:Package, 
        _ uri:(Package.Pinned) throws -> URI) 
        rethrows -> (current:[UInt8], menu:[UInt8])
    {
        var counts:[MaskedVersion: Int] = [:]
        for version:Version in availableVersions 
        {
            counts[package.versions[version].triplet, default: 0] += 1
        }
        
        func display(_ version:Version) -> String
        {
            let precise:PreciseVersion = package.versions[version]
            let triplet:MaskedVersion = precise.triplet
            if case 1? = counts[triplet] 
            {
                return triplet.description
            }
            else 
            {
                return precise.quadruplet.description
            }
        }
        
        var items:[HTML.Element<Never>] = []
            items.reserveCapacity(availableVersions.count)
        for version:Version in availableVersions.reversed()
        {
            let text:String = display(version)
            if  version == currentVersion
            {
                items.append(.li(.span(text) { ("class", "current") }))
            }
            else 
            {
                let uri:URI = try uri(.init(package, at: version))
                items.append(.li(.a(text) { ("href", uri.description) }))
            }
        }
        let menu:HTML.Element<Never> = .ol(items: items)
        let label:(HTML.Element<Never>, HTML.Element<Never>) = 
        (
            .span(package.id.title)        { ("class", "package") },
            .span(display(currentVersion)) { ("class", "version") }
        )
        let rendered:(current:[UInt8], menu:[UInt8]) = 
        (
            current: label.0.rendered(as: [UInt8].self) + 
                    label.1.rendered(as: [UInt8].self),
            menu: menu.rendered(as: [UInt8].self)
        )
        return rendered
    }
}

extension Ecosystem
{
    func render(topics:Topics) -> DOM.Template<Topics.Key, [UInt8]>?
    {
        if topics.isEmpty 
        {
            return nil 
        }
        
        var sections:[HTML.Element<Topics.Key>] = []
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
                sections.append(self.render(section: segregated, heading: heading.rawValue))
            }
        }
        
        if !topics.requirements.isEmpty
        {
            let requirements:[Topics.Sublist: [Module.Culture: [Symbol.Card]]] = 
                topics.requirements.mapValues { [.primary: $0] }
            sections.append(self.render(section: requirements, heading: "Requirements"))
        }
        if !topics.members.isEmpty
        {
            sections.append(self.render(section: topics.members, heading: "Members"))
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
                sections.append(self.render(section: list, heading: heading.rawValue))
            }
        }
        
        if !topics.removed.isEmpty
        {
            sections.append(self.render(section: topics.removed, 
                heading: "Removed Members"))
        }
        
        return sections.isEmpty ? nil : 
            .init(freezing: .div(sections) { ("class", "lower-container") })
    }
    
    private 
    func render(section segregated:[Module.Culture: [Symbol.Conditional]], heading:String)
        -> HTML.Element<Topics.Key>
    {
        var elements:[HTML.Element<Topics.Key>] = []
            elements.reserveCapacity(2 * segregated.count + 1)
            elements.append(.h2(heading))
        for (culture, targets):(Module.Culture, [Symbol.Conditional]) in self.sort(segregated)
        {
            if let culture:HTML.Element<Topics.Key> = self.renderHeading(culture)
            {
                elements.append(.h3(culture))
            }
            let items:[HTML.Element<Topics.Key>] = self.sort(targets).map 
            {
                let (target, host):(Symbol.Conditional, Symbol.Index) = $0
                let signature:HTML.Element<Topics.Key> = .a(.render(path: self[host].path))
                {
                    ("href", .anchor(.uri(.symbol(target.index))))
                    ("class", "signature")
                }
                if  let constraints:HTML.Element<Topics.Key> = .render(.text(escaped: "When"), 
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
    func render(subsection segregated:[Module.Culture: [Symbol.Card]], heading:String)
        -> HTML.Element<Topics.Key>
    {
        var elements:[HTML.Element<Topics.Key>] = []
            elements.reserveCapacity(2 * segregated.count + 1)
            elements.append(.h3(heading))
        for (culture, cards):(Module.Culture, [Symbol.Card]) in 
            self.sort(segregated)
        {
            if let culture:HTML.Element<Topics.Key> = self.renderHeading(culture)
            {
                elements.append(.h4(culture))
            }
            let items:[HTML.Element<Topics.Key>] = self.sort(cards).map 
            {
                (card:Symbol.Card) in 
                
                let signature:HTML.Element<Topics.Key> = 
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
    func render(
        section segregated:[Topics.Sublist: [Module.Culture: [Symbol.Card]]], 
        heading:String)
        -> HTML.Element<Topics.Key>
    {
        var elements:[HTML.Element<Topics.Key>] = [.h2(heading)]
        for sublist:Topics.Sublist in Topics.Sublist.allCases
        {
            if let segregated:[Module.Culture: [Symbol.Card]] = segregated[sublist]
            {
                elements.append(self.render(subsection: segregated, heading: sublist.heading))
            }
        }
        return .section(elements) { ("class", "topics") }
    }
    private 
    func renderHeading(_ culture:Module.Culture) -> HTML.Element<Topics.Key>?
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
/*  
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
*/
