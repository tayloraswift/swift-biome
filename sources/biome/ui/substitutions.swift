import HTML

extension Ecosystem 
{
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
    
    func generateFixedElements(for composite:Symbol.Composite, at version:Version) 
        -> [Page.Anchor: DOM.Template<Index, [UInt8]>]
    {
        // let dynamic:(sections:[Element], cards:Set<Int>) = self.dynamicContent(witness: witness)
        
        let base:Symbol = self[composite.base]
        
        guard let declaration:Symbol.Declaration = 
            self.declaration(for: composite.base, at: version)
        else 
        {
            return [:]
        }
        
        var substitutions:[Page.Anchor: HTML.Element<Index>] = 
        [
            .title:        .text(escaping: base.name), 
            .headline:     .h1(base.name), 
            .constants:    .text(escaped: Self.constants(filter: [])),
            
            .navigator:     self.navigator(base: base, host: composite.host),
            
            .kind:         .text(escaping: base.color.title),
            .fragments:    .render(fragments: declaration.fragments),
            // .dynamic:       Element[.div]
            // {
            //     ["lower-container"]
            // }
            // content:
            // {
            //     dynamic.sections
            // },
        ]
        
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
} 


/* private 
func present(reference resolved:ResolvedLink) -> StaticElement
{
    let components:[(text:String, uri:URI)], 
        tail:(text:String, uri:URI)

    switch resolved
    {
    case .article(let article): 
        return StaticElement.link(self.articles[article].conquistador.title, 
            to: self.format(uri: self.uri(article: article)), 
            internal: true)
    
    case .package(let package):
        components  = []
        tail        = 
        (
            self.biome.packages[package].name,
            self.biome.uri(package: package)
        )
    
    case .module(let module):
        components  = []
        tail        = 
        (
            self.biome.modules[module].title,
            self.biome.uri(module: module)
        )
    case .symbol(let witness, victim: let victim, components: let limit):
        var reversed:[(text:String, uri:URI)] = []
        var next:Int?       = victim ?? self.biome.symbols[witness].parent
        while let index:Int = next, reversed.count < limit - 1
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


private 
func link(package:Int) -> Element
{
    .link(self.biome.packages[package].name, to: self.format(uri: self.uri(package: package)), internal: true)
}
private 
func link(module:Int) -> Element
{
    .link(self.biome.modules[module].title, to: self.format(uri: self.uri(module: module)), internal: true)
}

private 
func highlight(_ text:String, _ color:Highlight, link:Int?) -> Element
{
    return link.map { self.highlight(text, color, link: $0) } ?? .highlight(text, color)
}
private 
func highlight(_ text:String, _ color:Highlight, link index:Int) -> Element
{
    .link(text, to: self.format(uri: self.uri(witness: index, victim: nil)), internal: true)
    {
        ["syntax-type"] 
    }
} */
