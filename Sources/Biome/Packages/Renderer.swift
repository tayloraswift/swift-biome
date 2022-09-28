import DOM
import HTML
import SVG
import PieCharts
import SymbolGraphs
import URI

extension Packages
{
    func renderFields(for index:Package.Index, version:Version) 
        -> [Page.Key: DOM.Flattened<Ecosystem.Index>]
    {
        let package:Package = self[index]
        let kind:String 
        switch package.kind 
        {
        case .swift:        kind = "Standard Library"
        case .core:         kind = "Core Libraries"
        case .community:    kind = "Package"
        }
        let title:String = package.title
        var substitutions:[Page.Key: HTML.Element<Ecosystem.Index>] = 
        [
            .title:        .init(title), 
            .headline:     .h1(title), 
            .kind:         .init(escaped: kind)
        ]

        let revision:Branch.Revision = package.tree[version]
        if !revision.pins.isEmpty
        {
            substitutions[.dependencies] = .table( 
                .thead(.tr(.td(escaped: "Dependency"), .td(escaped: "Version"))),
                .tbody(revision.pins.sorted 
                {
                    $0.key < $1.key 
                }
                .map 
                {
                    (item:(key:Package.Index, value:Version)) in 

                    let dependency:Package = self[item.key]
                    let link:HTML.Element<Ecosystem.Index> = 
                        .a(dependency.tree[item.value].version.description, 
                            attributes: [.init(anchor: .package(item.key))])
                    return .tr(.td(dependency.name), .td(link))
                }))
        }
        let pie:SVG.Root<Never> = Pie.svg(
        [
            .init(weight: 57, classes: "-pink"),
            .init(weight: 27, classes: "-yellow"),
            .init(weight: 16, classes: "-white"),
        ])
        substitutions[.discussion] = .div(
            .div(.init(escaped: pie.rendered(as: [UInt8].self)), 
                attributes: [.class("pie-color")]),
            .div(attributes: [.class("pie-geometry")]),
            attributes: [.class("pie")])

        return substitutions.mapValues { .init(freezing: $0) }
    }
    func renderFields(for index:Module.Index) -> [Page.Key: DOM.Flattened<Ecosystem.Index>]
    {
        let module:Module = self[index]
        let title:String = self[index.nationality].title(module.title)
        let substitutions:[Page.Key: HTML.Element<Ecosystem.Index>] = 
        [
            .title:        .init(title), 
            .headline:     .h1(module.title), 
            .kind:         .init(escaped: "Module"),
            .fragments:    .render(fragments: module.fragments) { (_:Never) -> Ecosystem.Index in },
            .culture:       self.link(package: index.nationality),
        ]
        return substitutions.mapValues { .init(freezing: $0) }
    }
    func renderFields(for index:Article.Index, excerpt:Article.Metadata) 
        -> [Page.Key: DOM.Flattened<Ecosystem.Index>]
    {
        let title:String = self[index.nationality].title(excerpt.headline.plain)
        let substitutions:[Page.Key: HTML.Element<Ecosystem.Index>] = 
        [
            .title:        .init(title), 
            .headline:     .h1(.init(escaped: excerpt.headline.formatted)), 
            .kind:         .init(escaped: "Article"),
            .culture:       self.link(module: index.culture),
        ]
        return substitutions.mapValues { .init(freezing: $0) }
    }
    func renderFields(for composite:Composite, 
        declaration:Declaration<Symbol.Index>, 
        facts:Symbol.Predicates<Symbol.Index>) 
        -> [Page.Key: DOM.Flattened<Ecosystem.Index>]
    {
        let base:Symbol = self[composite.base]
        let title:String = self[composite.nationality].title(base.name)
        var substitutions:[Page.Key: HTML.Element<Ecosystem.Index>] = 
        [
            .title:        .init(title), 
            .headline:     .h1(base.name), 
            .kind:         .init(base.community.title),
            .fragments:    .render(fragments: declaration.fragments, 
                transform: Ecosystem.Index.symbol(_:)),
            
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
        
        if composite.diacritic.host.culture != composite.culture 
        {
            substitutions[.namespace] = .span(self.link(module: composite.diacritic.host.culture), 
                attributes: [.class("namespace")])
        }
        if composite.base.culture != composite.culture 
        {
            substitutions[.base] = .span(self.link(module: composite.base.culture), 
                attributes: [.class("base")])
        }
        
        return substitutions.mapValues { .init(freezing: $0) }
    }
    func renderFields(for choices:[Composite], uri:URI) -> [Page.Key: [UInt8]]
    {
        // does not use percent-encoding
        var name:String = ""
        // trim the root
        for vector:URI.Vector? in uri.path.dropFirst()
        {
            switch vector
            {
            case  nil: 
                name += "/."
            case .pop?: 
                name += "/.."
            case .push(let component)?: 
                name += "/\(component)"
            }
        }
        let substitutions:[Page.Key: HTML.Element<Never>] = 
        [
            .title:        .init(escaped: "Disambiguation Page"), 
            .headline:     .h1(name), 
            .kind:         .init(escaped: "Disambiguation Page"),
            .summary:      .p(escaped: "This link could refer to multiple symbols."),
        ]
        return substitutions.mapValues { $0.node.rendered(as: [UInt8].self) }
    }
    
    private 
    func renderNotes(for composite:Composite,
        declaration:Declaration<Symbol.Index>, 
        facts:Symbol.Predicates<Symbol.Index>) 
        -> HTML.Element<Ecosystem.Index>?
    {
        fatalError("obsoleted")
    }
    private 
    func renderBreadcrumbs(for composite:Composite) -> HTML.Element<Ecosystem.Index>
    {
        let base:Symbol = self[composite.base]
        
        var crumbs:[HTML.Element<Ecosystem.Index>] = [.li(base.name)]
        var next:Symbol.Index? = composite.host ?? base.shape?.target.atom
        while let index:Symbol.Index = next
        {
            let current:Symbol = self[index]
            crumbs.append(.li(.a(.highlight(current.name, .type), 
                attributes: [.init(anchor: .symbol(index))])))
            next = current.shape?.target.atom
        }
        crumbs.reverse()
        return .ol(crumbs) 
    }
    
    private 
    func link(package:Package.Index) -> HTML.Element<Ecosystem.Index>
    {
        .a(self[package].name, attributes: [.init(anchor: .package(package))])
    }
    private 
    func link(module:Module.Index) -> HTML.Element<Ecosystem.Index>
    {
        .a(self[module].title, attributes: [.init(anchor: .module(module))])
    }
} 

extension Packages
{
    // func render(choices segregated:[Module.Index: [Page.Card]]) 
    //     -> DOM.Flattened<Page.Topics.Key>
    // {
    //     var elements:[HTML.Element<Page.Topics.Key>] = []
    //         elements.reserveCapacity(2 * segregated.count)
    //     for (culture, cards):(Module.Index, [Page.Card]) in self.sort(segregated)
    //     {
    //         elements.append(.h4(self.renderHeading(culture)))
    //         elements.append(self.render(cards: cards))
    //     }
    //     return .init(freezing: .div(.section(elements, attributes: [.class("topics choices")])))
    // }
    // func render(modulelist:[Module]) -> DOM.Flattened<Page.Topics.Key>
    // {
    //     let items:[HTML.Element<Page.Topics.Key>] = 
    //         modulelist.sorted(by: { $0.id.value < $1.id.value }).map
    //     {
    //         (module:Module) in 
            
    //         .li(.a(.render(path: module.path), attributes: 
    //         [
    //             .init(anchor: .href(.module(module.index))), 
    //             .class("signature")
    //         ]))
    //     }
    //     let list:HTML.Element<Page.Topics.Key> = .ul(items)
    //     let heading:HTML.Element<Page.Topics.Key> = .h2(escaped: "Modules")
    //     return .init(freezing: .div(.section(heading, list, attributes: [.class("related")])))
    // }
}
