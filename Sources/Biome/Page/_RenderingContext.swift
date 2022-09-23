import DOM
import HTML
import Notebook

struct _MetadataLoadingError:Error 
{
}
struct _DeclarationLoadingError:Error 
{
}
struct _SymbolInfo 
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

        init(base:SymbolReference, host:SymbolReference?, 
            context:__shared Package.Context, 
            cache:inout _ReferenceCache) throws 
        {
            self.base = base 
            self.host = host 
            self.elements = []
            self.elements.reserveCapacity(self.host == nil ? 
                base.path.count - 1 : 
                base.path.count)
            var next:SymbolReference? = self.host ?? base.shape.map 
            {
                cache.load($0.target, context: context)
            }
            while let current:SymbolReference = next 
            {
                self.elements.append((display: current.name, uri: current.uri))
                next = current.shape.map 
                {
                    cache.load($0.target, context: context)
                }
            }
        }
    }
    let culture:
    (
        composite:ModuleReference, 
        base:ModuleReference?,
        host:ModuleReference?
    )
    let breadcrumbs:Breadcrumbs
    let conditions:Organizer.Conditional
    let topics:[UInt8]?
    let notes:SymbolTopics.Notes?
    let fragments:Notebook<Highlight, String>
    let availability:Availability

    init(_ composite:Composite, 
        context:__shared Package.Context, 
        cache:inout _ReferenceCache) throws 
    {
        // note: context is anisotropic
        assert(context.local.nationality == composite.nationality)

        let base:SymbolReference = try cache.load(composite.base, context: context)
        self.culture.composite = try cache.load(composite.culture, context: context)

        let declaration:Declaration<Atom<Symbol>>?
        let topics:SymbolTopics
        if let compound:Compound = composite.compound 
        {
            declaration = context[compound.base.nationality]?.declaration(for: compound.base)
            
            topics = .init(notes: .feature(
                protocol: try .init(base, context: context, cache: &cache)))
            
            self.culture.base = compound.base.culture == compound.culture ? nil :
                try cache.load(compound.base.culture, context: context)
            self.culture.host = compound.host.culture == compound.culture ? nil :
                try cache.load(compound.host.culture, context: context)
            
            self.breadcrumbs = try .init(base: _move base, 
                host: try cache.load(compound.host, context: context), 
                context: context, 
                cache: &cache)
        }
        else 
        {
            declaration = context.local.declaration(for: composite.base)

            topics = try .init(for: composite.base, base: base, 
                context: context, 
                cache: &cache)
            
            self.culture.base = nil
            self.culture.host = nil

            self.breadcrumbs = try .init(base: _move base, host: nil, 
                context: context, 
                cache: &cache)
        }

        guard let declaration:Declaration<Atom<Symbol>>
        else 
        {
            throw _DeclarationLoadingError.init()
        }

        self.conditions = try .init(declaration.extensionConstraints, 
            context: context, 
            cache: &cache)
        self.fragments = try declaration.fragments.map 
        {
            try cache.load($0, context: context).uri
        }
        self.availability = declaration.availability
        self.topics = try topics.html(context: context, cache: &cache)?.node
            .rendered(as: [UInt8].self)
        self.notes = topics.notes 
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
                html = self.culture.base.map 
                { 
                    .span($0.html, attributes: [.class("base")]) 
                }
            case .breadcrumbs: 
                html = .ol(self.breadcrumbs.reversed()) 
            
            case .consumers: 
                html = nil 
            
            case .culture: 
                html = self.culture.composite.html 
            
            case .dependencies: 
                html = nil
            
            case .discussion: 
                fatalError("unimplemented")
            
            case .fragments: 
                let fragments:[HTML.Element<Never>] = self.fragments.map 
                {
                    .highlight($0.text, $0.color, uri: $0.link)
                }
                html = .section(.pre(.code(fragments, attributes: [.class("swift")])), 
                    attributes: [.class("declaration")])
            
            case .headline: 
                html = .h1(self.base.name)
            
            case .kind: 
                return [UInt8].init(self.base.community.title.utf8)
            
            case .namespace: 
                html = self.culture.host.map 
                { 
                    .span($0.html, attributes: [.class("namespace")]) 
                }
            case .notes: 
                html = self.renderNotes()
            
            case .notices: 
                fatalError("unimplemented")
            case .pin: 
                fatalError("unimplemented") 
            
            case .platforms: 
                html = .render(availability: self.availability.platforms)

            case .summary: 
                fatalError("unimplemented")
            
            case .topics: 
                return self.topics 
            
            case .versions: 
                fatalError("unimplemented")
            }
            return html?.node.rendered(as: [UInt8].self)
        }
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
}