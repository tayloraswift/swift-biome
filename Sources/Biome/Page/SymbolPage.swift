import DOM
import HTML
import Notebook

struct _MetadataLoadingError:Error 
{
}
struct _DeclarationLoadingError:Error 
{
}

extension SymbolPage 
{
    struct Breadcrumbs:RandomAccessCollection
    {
        let host:SymbolReference?
        let base:SymbolReference 
        private(set)
        var elements:[(display:String, uri:String)]

        var startIndex:Int 
        {
            -1
        }
        var endIndex:Int 
        {
            self.elements.endIndex
        }
        subscript(index:Int) -> HTML.Element<Never> 
        {
            if index == self.startIndex 
            {
                return .li(self.base.name)
            }
            else 
            {
                let element:(display:String, uri:String) = self.elements[index]
                return .li(.highlight(element.display, .type, uri: element.uri))
            }
        }
    }
}
extension SymbolPage.Breadcrumbs 
{
    init(base:SymbolReference, host:SymbolReference?, 
        context:__shared some PackageContext, 
        cache:inout ReferenceCache) throws 
    {
        self.base = base 
        self.host = host 
        self.elements = []
        self.elements.reserveCapacity(self.host == nil ? 
            base.path.count - 1 : 
            base.path.count)
        var next:SymbolReference? = try self.host ?? base.shape.map 
        {
            try cache.load($0.target, context: context)
        }
        while let current:SymbolReference = next 
        {
            self.elements.append((display: current.name, uri: current.uri))
            next = try current.shape.map 
            {
                try cache.load($0.target, context: context)
            }
        }
    }
}

extension SymbolPage 
{
    struct Names 
    {
        let breadcrumbs:Breadcrumbs
        let culture:
        (
            composite:ModuleReference, 
            base:ModuleReference?,
            host:ModuleReference?
        )
    }
}
extension SymbolPage.Names 
{
    init(_ symbol:Atom<Symbol>.Position, base:SymbolReference, 
        context:__shared AnisotropicContext, 
        cache:inout ReferenceCache) throws 
    {
        assert(context.local.nationality == symbol.nationality)

        self.culture.composite = try cache.load(symbol.culture, context: context)

        self.culture.base = nil
        self.culture.host = nil

        self.breadcrumbs = try .init(base: _move base, host: nil, 
            context: context, 
            cache: &cache)
    }
    init(_ compound:Compound.Position, base:SymbolReference, 
        context:__shared AnisotropicContext, 
        cache:inout ReferenceCache) throws 
    {
        assert(context.local.nationality == compound.nationality)

        self.culture.composite = try cache.load(compound.culture, context: context)
        let host:SymbolReference = try cache.load(compound.host, context: context)

        let compound:Compound = compound.atoms

        self.culture.base = compound.base.culture == compound.culture ? nil :
            try cache.load(compound.base.culture, context: context)
        self.culture.host = compound.host.culture == compound.culture ? nil :
            try cache.load(compound.host.culture, context: context)
        
        self.breadcrumbs = try .init(base: _move base, host: _move host, 
            context: context, 
            cache: &cache)
    }
}
struct SymbolPage 
{
    let evolution:Evolution

    let names:Names
    let conditions:Organizer.Conditional
    let notes:SymbolTopics.Notes?
    let fragments:Notebook<Highlight, String>
    let availability:Availability

    let overview:[UInt8]?
    let discussion:[UInt8]?
    let topics:[UInt8]?

    init(_ symbol:Atom<Symbol>.Position, 
        documentation:__shared DocumentationExtension<Never>, 
        evolution:Evolution,
        context:__shared AnisotropicContext, 
        cache:inout ReferenceCache) throws 
    {
        assert(context.local.nationality == symbol.nationality)

        guard   let declaration:Declaration<Atom<Symbol>> = 
                    context.local.declaration(for: symbol.atom)
        else 
        {
            throw _DeclarationLoadingError.init()
        }

        let base:SymbolReference = try cache.load(symbol, context: context)
        try self.init(documentation: documentation, 
            declaration: declaration, 
            evolution: evolution, 
            topics: try .init(for: symbol.atom, base: base, 
                context: context, 
                cache: &cache), 
            names: try .init(symbol, base: _move base, 
                context: context, 
                cache: &cache), 
            context: context, 
            cache: &cache)
    }
    init(_ compound:Compound.Position, 
        documentation:__shared DocumentationExtension<Never>, 
        evolution:Evolution,
        context:__shared AnisotropicContext, 
        cache:inout ReferenceCache) throws 
    {
        assert(context.local.nationality == compound.nationality)

        guard   let declaration:Declaration<Atom<Symbol>> = 
                    context[compound.base.nationality]?.declaration(for: compound.atoms.base)
        else 
        {
            throw _DeclarationLoadingError.init()
        }
        
        let base:SymbolReference = try cache.load(compound.base, context: context)

        try self.init(documentation: documentation, 
            declaration: declaration, 
            evolution: evolution, 
            topics: .init(notes: .feature(
                protocol: try .init(base, context: context, cache: &cache))), 
            names: try .init(compound, base: _move base, 
                context: context, 
                cache: &cache), 
            context: context, 
            cache: &cache)
    }
    init(documentation:__shared DocumentationExtension<Never>, 
        declaration:Declaration<Atom<Symbol>>,
        evolution:Evolution, 
        topics:SymbolTopics, 
        names:Names,
        context:__shared AnisotropicContext, 
        cache:inout ReferenceCache) throws 
    {
        self.evolution = evolution
        self.conditions = try .init(declaration.extensionConstraints, 
            context: context, 
            cache: &cache)
        self.fragments = try declaration.fragments.map 
        {
            try cache.load($0, context: context).uri
        }
        self.availability = declaration.availability
        self.notes = topics.notes 

        self.overview = try cache.link(documentation.card, context: context)
        self.discussion = try cache.link(documentation.body, context: context)

        self.topics = try topics.html(context: context, cache: &cache)?.node
            .rendered(as: [UInt8].self)
        self.names = names 
    }

    var breadcrumbs:Breadcrumbs 
    {
        self.names.breadcrumbs
    }
    var base:SymbolReference 
    {
        self.breadcrumbs.base 
    }
    var host:SymbolReference?
    {
        self.breadcrumbs.host
    }

    func _render(template:DOM.Flattened<Page.Key>) -> [UInt8]
    {
        template.rendered(as: [UInt8].self)
        {
            (key:Page.Key) -> [UInt8]? in 

            let html:HTML.Element<Never>?
            switch key
            {
            case .summary: 
                return self.overview ?? [UInt8].init("No overview available.".utf8)
            case .discussion: 
                return self.discussion
            case .topics: 
                return self.topics 

            case .title: 
                fatalError("unimplemented") 
            case .constants: 
                fatalError("unimplemented") 
            
            case .availability: 
                html = .render(availability: 
                (
                    self.availability.swift, 
                    self.availability.general
                ))
            case .base: 
                html = self.names.culture.base.map 
                { 
                    .span($0.html, attributes: [.class("base")]) 
                }
            case .breadcrumbs: 
                html = .ol(self.breadcrumbs.reversed()) 
            
            case .consumers: 
                html = nil 
            
            case .culture: 
                html = self.names.culture.composite.html 
            
            case .dependencies: 
                html = nil
            
            case .fragments: 
                html = self.renderFragments()
            
            case .headline: 
                html = .h1(self.base.name)
            
            case .kind: 
                return [UInt8].init(self.base.community.title.utf8)
            
            case .namespace: 
                html = self.names.culture.host.map 
                { 
                    .span($0.html, attributes: [.class("namespace")]) 
                }
            case .notes: 
                html = self.renderNotes()
            
            case .notices: 
                if let newer:String = self.evolution.newer 
                {
                    html = .div(.div(.p()), .div(.p(
                            .init(escaped: "There’s a "),
                            .a("newer version", attributes: [.href(newer)]),
                            .init(escaped: " of this documentation available."))), 
                        attributes: [.class("notice extinct")])
                }
                else 
                {
                    html = nil
                }
            
            case .pin: 
                let package:HTML.Element<Never> = 
                    .span(self.evolution.current.package.title, 
                        attributes: [.class("package")])
                let branch:HTML.Element<Never> = 
                    .span(self.evolution.current.branch.description, 
                        attributes: [.class("version")]) 
                return package.node.rendered(as: [UInt8].self) + 
                    branch.node.rendered(as: [UInt8].self)
            
            case .platforms: 
                html = .render(availability: self.availability.platforms)
            
            case .versions: 
                html = self.renderAvailableVersions()
            }
            return html?.node.rendered(as: [UInt8].self)
        }
    }

    private 
    func renderFragments() -> HTML.Element<Never>
    {
        let fragments:[HTML.Element<Never>] = self.fragments.map 
        {
            .highlight($0.text, $0.color, uri: $0.link)
        }
        return .section(.pre(.code(fragments, attributes: [.class("swift")])), 
            attributes: [.class("declaration")])
    }
    private 
    func renderNotes() -> HTML.Element<Never>? 
    {
        var items:[HTML.Element<Never>] = []
        switch self.notes 
        {
        case nil: 
            break 
        
        case .feature(protocol: let coyote)?:
            items.append(.li(.p(.init(escaped: "Available because "),
                .code(.highlight(escaped: "Self", .type, uri: self.host?.uri),
                .init(escaped: " conforms to "),
                .code(.highlight(coyote.display.name, .type, uri: coyote.uri)),
                .init(escaped: "."))))) 
        
        case .member(overridden: let overridden)?: 
            for overridden:Organizer.Item<Organizer.Unconditional> in overridden
            {
                let prose:String 
                switch overridden.display.community 
                {
                case .protocol: 
                    prose = "Implements requirement of "
                case _:
                    prose = "Overrides member of "
                }
                items.append(.li(.p(.init(escaped: prose), 
                    .code(.highlight(overridden.display.name, .type, uri: overridden.uri)), 
                    .init(escaped: "."))))
            }

        case .requirement(restated: let restated)?:
            items.append(.li(.p(escaped: "Required.", attributes: [.class("required")])))
            
            for restated:Organizer.Item<Organizer.Unconditional> in restated
            {
                items.append(.li(.p(.init(escaped: "Restates requirement of "),
                    .code(.highlight(restated.display.name, .type, uri: restated.uri)),
                    .init(escaped: "."))))
            }
        }
        
        let conditions:[HTML.Element<Never>] = self.conditions.html 
        if !conditions.isEmpty
        {
            let sentence:[HTML.Element<Never>] = 
                [.init(escaped: "Available when ")] + conditions + [.init(escaped: ".")]
            items.append(.li(.p(sentence)))
        }
        
        return items.isEmpty ? nil : .ul(items, attributes: [.class("notes")])
    }
    private 
    func renderAvailableVersions() -> HTML.Element<Never> 
    {
        .ol(self.evolution.items.map 
        {
            let text:String = $0.label.description
            if let uri:String = $0.uri 
            {
                return .li(.a(text, attributes: [.href(uri)]))
            }
            else 
            {
                return .li(.span(text), attributes: [.class("current")])
            }
        })
    }
}