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
}
extension Ecosystem 
{
    func generateArticle(_ composite:Symbol.Composite, pins:[Package.Index: Version])
        -> Article.Template<[Index]>
    {
        self.baseTemplate(composite, pins: pins).map 
        { 
            $0.map(self.expand(link:)) 
        } ?? .init()
    }
    
    func generateExcerpt(_ composite:Symbol.Composite, pins:[Package.Index: Version])
        -> DOM.Template<[Index], [UInt8]>?
    {
        self.baseTemplate(composite, pins: pins).flatMap
        { 
            $0.summary.isEmpty ? nil : $0.summary.map(self.expand(link:)) 
        }
    }
}
extension Ecosystem
{
    func generateCards(_ composite:Symbol.Composite, pins:[Package.Index: Version]) 
        -> DOM.Template<CardKey, [UInt8]>?
    {
        guard let host:Symbol.Index = composite.natural 
        else 
        {
            // no dynamics for synthesized features
            return nil
        }
        
        let topics:Topics = self.organizeTopics(forHost: host, pins: pins)
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
            sections.append(self.generateSection(topics.requirements, 
                heading: "Requirements", 
                pins: pins))
        }
        if !topics.members.isEmpty
        {
            sections.append(self.generateSection(topics.members, 
                heading: "Members", 
                pins: pins))
        }
        
        for heading:Topics.List in 
        [
            .conformers,
            .conformances,
            .subclasses,
            .implies,
        ]
        {
            if let list:[Module.Culture: [Symbol.Conditional]] = topics.lists[heading]
            {
                sections.append(self.generateSection(list, heading: heading.rawValue))
            }
        }
        
        return sections.isEmpty ? nil : 
            .init(freezing: .div(sections) { ("class", "lower-container") })
    }
    
    private 
    func generateSection(_ segregated:[Module.Culture: [Symbol.Conditional]], heading:String)
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
            let items:[HTML.Element<CardKey>] = targets.map 
            {
                (target:Symbol.Conditional) -> (target:Symbol.Conditional, host:Symbol.Index) in 
                
                if  case .callable(_) = self[target.index].color, 
                    let host:Symbol.Index = self[target.index].shape?.index 
                {
                    return (target: target, host: host)
                }
                else 
                {
                    return (target: target, host: target.index)
                }
            }
            .sorted 
            {
                self[$0.host].path.lexicographicallyPrecedes(self[$1.host].path)
            }
            .map 
            {
                let (target, host):(Symbol.Conditional, Symbol.Index) = $0
                let signature:HTML.Element<CardKey> = .a(.render(path: self[host].path))
                {
                    ("href", .anchor(.uri(.symbol(target.index))))
                    ("class", "signature")
                }
                if target.conditions.isEmpty
                {
                    return .li(signature)
                }
                else 
                {
                    let constraints:HTML.Element<CardKey> = 
                        .render(.text(escaped: "When"), constraints: target.conditions) 
                    { 
                        .uri(.symbol($0)) 
                    } 
                    return .li([signature, constraints])
                }
            }
            
            elements.append(.ul(items: items))
        }
        return .section(elements) { ("class", "related") }
    }
    private 
    func generateSection(_ segregated:[Topics.Sublist: [Module.Culture: [Symbol.Composite]]], 
        heading:String, 
        pins:[Package.Index: Version])
        -> HTML.Element<CardKey>
    {
        var elements:[HTML.Element<CardKey>] = [.h2(heading)]
        for sublist:Topics.Sublist in Topics.Sublist.allCases
        {
            if let segregated:[Module.Culture: [Symbol.Composite]] = segregated[sublist]
            {
                elements.append(self.generateSubsection(segregated, heading: sublist.heading, pins: pins))
            }
        }
        return .section(elements) { ("class", "topics") }
    }
    private 
    func generateSubsection(_ segregated:[Module.Culture: [Symbol.Composite]], 
        heading:String, 
        pins:[Package.Index: Version])
        -> HTML.Element<CardKey>
    {
        var elements:[HTML.Element<CardKey>] = []
            elements.reserveCapacity(2 * segregated.count + 1)
            elements.append(.h3(heading))
        for (culture, composites):(Module.Culture, [Symbol.Composite]) in 
            self.sort(segregated)
        {
            if let culture:HTML.Element<CardKey> = self.generateCultureHeading(culture)
            {
                elements.append(.h4(culture))
            }
            let items:[HTML.Element<CardKey>] = self.sort(composites).map 
            {
                (composite:Symbol.Composite) in 
                
                let fragments:HTML.Element<CardKey> 
                if  let declaration:Symbol.Declaration = 
                    self.baseDeclaration(composite, pins: pins)
                {
                    fragments = .render(signature: declaration.signature)
                }
                else 
                {
                    // should be unreachable in practice
                    fragments = .code("<unavailable>")
                }
                let signature:HTML.Element<CardKey> = .a(fragments)
                {
                    ("href", .anchor(.uri(.composite(composite))))
                    ("class", "signature")
                }
                return .li([signature, .anchor(.excerpt(composite))])
            }
            elements.append(.ul(items: items))
        }
        return .section(elements) 
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
    func sort(_ composites:[Symbol.Composite]) -> [Symbol.Composite]
    {
        composites.sorted 
        {
            // this lexicographic ordering sorts by last path component first, 
            // and *then* by vending protocol (if applicable)
            let base:(Symbol, Symbol) = (self[$0.base], self[$1.base])
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
    func generateFields(_ composite:Symbol.Composite, pins:[Package.Index: Version]) 
        -> [PageKey: DOM.Template<Index, [UInt8]>]
    {
        let base:Symbol = self[composite.base]
        
        guard let declaration:Symbol.Declaration = 
            self.baseDeclaration(composite, pins: pins)
        else 
        {
            return [:]
        }
        
        var substitutions:[PageKey: HTML.Element<Index>] = 
        [
            .title:        .text(escaping: base.name), 
            .headline:     .h1(base.name), 
            .constants:    .text(escaped: Self.constants(filter: [])),
            
            .navigator:     self.navigator(base: base, host: composite.host),
            
            .kind:         .text(escaping: base.color.title),
            .culture:       self.link(module: composite.culture),
            .fragments:    .render(fragments: declaration.fragments, Ecosystem.Index.symbol(_:)),
        ]
        
        if composite.diacritic.host.module != composite.culture 
        {
            substitutions[.namespace] = .span(self.link(module: composite.diacritic.host.module))
            {
                ("class", "namespace")
            }
        }
        if composite.base.module != composite.culture 
        {
            substitutions[.base] = .span(self.link(module: composite.base.module))
            {
                ("class", "base")
            }
        }
        
        substitutions[.platforms] = .render(
            availability: declaration.availability.platforms)
        substitutions[.availability] = .render(
            availability: 
        (
            declaration.availability.swift, 
            declaration.availability.general
        ))
        
        return substitutions.mapValues(DOM.Template<Index, [UInt8]>.init(freezing:))
        /* if case nil = substitutions.index(forKey: .summary)
        {
            substitutions[.summary]     = Element[.p]
            {
                "No overview available."
            }
        }
        for origin:Int in dynamic.cards 
        {
            substitutions[.reference(.symbol(origin, victim: nil))] = self.symbols[origin].summary.map(self.fill(template:))
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
        
        let article:Article.Rendered<ResolvedLink>.Content = self.symbols[symbol.sponsor ?? witness]
        substitutions[.summary]     = article.summary.map(self.fill(template:))
        substitutions[.discussion]  = article.discussion.map(self.fill(template:)) */
    }
    
    private static 
    func constants(filter:[Package.ID]) -> String
    {
        // package name is alphanumeric, we should enforce this in 
        // `Package.ID`, otherwise this could be a security hole
        """
        includedPackages = [\(filter.map { "'\($0.string)'" }.joined(separator: ","))];
        """
    }
    private 
    func navigator(base:Symbol, host:Symbol.Index?) -> HTML.Element<Index>
    {
        var crumbs:[HTML.Element<Index>] = [.li(base.name)]
        var next:Symbol.Index? = host ?? base.shape?.index
        while let index:Symbol.Index = next
        {
            let current:Symbol = self[index]
            let crumb:HTML.Element<Index> = .a(.highlight(escaping: current.name, .type))
            {
                ("href", .anchor(.symbol(index)))
            }
            crumbs.append(.li(crumb))
            next = current.shape?.index
        }
        crumbs.reverse()
        return .ol(items: crumbs) { ("class", "breadcrumbs-container") }
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
