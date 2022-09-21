import DOM
import HTML

struct _SymbolInfo 
{
    let composite:Composite 
    let base:_ReferenceCache.AtomicReference 
    let host:_ReferenceCache.AtomicReference?
    let declaration:Declaration<Atom<Symbol>>
    let topics:_Topics 

    init(_ composite:Composite, 
        context:__shared Package.Context, 
        cache:inout _ReferenceCache) throws 
    {
        // note: context is anisotropic
        assert(context.local.nationality == composite.nationality)

        let base:_ReferenceCache.AtomicReference = try cache.load(composite.base, 
            context: context)
        if let compound:Compound = composite.compound 
        {
            guard   let declaration:Declaration<Atom<Symbol>> = 
                        context[compound.base.nationality]?.declaration(for: compound.base)
            else 
            {
                fatalError("unimplemented")
            }

            self.host = try cache.load(compound.host, context: context)
            self.topics = .init()
            self.declaration = declaration
        }
        else 
        {
            guard   let metadata:Symbol.Metadata = 
                        context.local.metadata(local: composite.base),
                    let declaration:Declaration<Atom<Symbol>> = 
                        context.local.declaration(for: composite.base)
            else 
            {
                fatalError("unimplemented")
            }

            self.host = nil
            self.declaration = declaration

            var organizer:_Topics.Organizer = .init()
            try organizer.organize(metadata.primary, of: base, 
                diacritic: composite.diacritic,
                culture: .primary,
                context: context,
                cache: &cache)
            
            for (culture, accepted):(Atom<Module>, Branch.SymbolTraits) in metadata.accepted 
            {
                try organizer.organize(accepted, of: base, 
                    diacritic: .init(host: composite.base, culture: culture), 
                    culture: .accepted(try cache.name(of: culture, context: context)),
                    context: context,
                    cache: &cache)
            }
            for (consumer, versions):(Package.Index, [Version: Set<Atom<Module>>]) in 
                context.local.revision.consumers
            {
                guard   let pinned:Package.Pinned = context[consumer], 
                        let consumers:Set<Atom<Module>> = versions[pinned.version]
                else 
                {
                    continue 
                }
                for culture:Atom<Module> in consumers 
                {
                    let diacritic:Diacritic = .init(host: composite.base, culture: culture)
                    if let extra:Symbol.ForeignMetadata = pinned.metadata(foreign: diacritic)
                    {
                        try organizer.organize(extra.traits, of: base, 
                            diacritic: diacritic, 
                            culture: .nonaccepted(try cache.name(of: culture, context: context)),
                            context: context,
                            cache: &cache)
                    }
                }
            }
            if  case .protocol = base.community, 
                let roles:Branch.SymbolRoles = metadata.roles 
            {
                try organizer.organize(roles, context: context, cache: &cache)
            }

            self.topics = .init(_move organizer)
        }
        self.base = base 
        self.composite = composite 
    }

    func _render(template:DOM.Flattened<Page.Key>) -> [UInt8]
    {
        template.rendered(as: [UInt8].self)
        {
            (key:Page.Key) -> [UInt8]? in 

            let html:HTML.Element<Never>
            switch key
            {
            case .title: 
                fatalError("unimplemented") 
            case .constants: 
                fatalError("unimplemented") 
            case .availability: 
                fatalError("unimplemented") 
            case .base: 
                fatalError("unimplemented")
            case .breadcrumbs: 
                fatalError("unimplemented")
            case .consumers: 
                fatalError("unimplemented")
            case .culture: 
                fatalError("unimplemented") 
            case .dependencies: 
                fatalError("unimplemented") 
            case .discussion: 
                fatalError("unimplemented")
            case .fragments: 
                fatalError("unimplemented")
            
            case .headline: 
                html = .h1(self.base.name)
            
            case .kind: 
                return [UInt8].init(self.base.community.title.utf8)
            
            case .namespace: 
                fatalError("unimplemented") 
            case .notes: 
                fatalError("unimplemented") 
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
            return html.node.rendered(as: [UInt8].self)
        }
    }
}