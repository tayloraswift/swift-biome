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
    let culture:
    (
        composite:ModuleReference, 
        base:ModuleReference?,
        host:ModuleReference?
    )
    let base:SymbolReference 
    let host:SymbolReference?

    let conditions:Organizer.Conditional
    let topics:SymbolTopics 

    let fragments:Notebook<Highlight, String>

    init(_ composite:Composite, 
        context:__shared Package.Context, 
        cache:inout _ReferenceCache) throws 
    {
        // note: context is anisotropic
        assert(context.local.nationality == composite.nationality)

        self.base = try cache.load(composite.base, context: context)
        self.culture.composite = try cache.load(composite.culture, context: context)

        let declaration:Declaration<Atom<Symbol>>?
        if let compound:Compound = composite.compound 
        {
            declaration = context[compound.base.nationality]?.declaration(for: compound.base)
            
            self.host = try cache.load(compound.host, context: context)
            self.topics = .init(notes: .feature(
                protocol: try .init(self.base, context: context, cache: &cache)))
            
            self.culture.base = compound.base.culture == compound.culture ? nil :
                try cache.load(compound.base.culture, context: context)
            self.culture.host = compound.host.culture == compound.culture ? nil :
                try cache.load(compound.host.culture, context: context)
        }
        else 
        {
            declaration = context.local.declaration(for: composite.base)

            self.host = nil
            self.topics = try .init(for: composite.base, base: self.base, 
                context: context, 
                cache: &cache)
            
            self.culture.base = nil
            self.culture.host = nil
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
                fatalError("unimplemented") 
            case .base: 
                html = self.culture.base.map 
                { 
                    .span($0.html, attributes: [.class("base")]) 
                }
            case .breadcrumbs: 
                fatalError("unimplemented")
            case .consumers: 
                fatalError("unimplemented")
            case .culture: 
                html = self.culture.composite.html 
            
            case .dependencies: 
                fatalError("unimplemented") 
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
                html = self.notes()
            case .notices: 
                fatalError("unimplemented")
            case .pin: 
                fatalError("unimplemented") 
            case .platforms: 
                fatalError("unimplemented")
            case .summary: 
                fatalError("unimplemented")
            case .topics: 
                fatalError("unimplemented")
            case .versions: 
                fatalError("unimplemented")
            }
            return html?.node.rendered(as: [UInt8].self)
        }
    }

    private 
    func notes() -> HTML.Element<Never>? 
    {
        var items:[HTML.Element<Never>] = []
        switch self.topics.notes 
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