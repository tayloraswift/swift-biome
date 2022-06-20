import HTML

@frozen public 
enum PageKey:Hashable, Sendable
{
    case title 
    case constants 
    
    case availability 
    case base
    case breadcrumbs
    case cards
    case culture 
    case discussion
    case fragments
    case headline
    case introduction
    case kind
    case namespace 
    case notes 
    case pin 
    case platforms
    case summary
    case versions
} 
enum CardKey:Hashable, Sendable 
{
    case excerpt(Symbol.Composite)
    case uri(Ecosystem.Index)
}

extension Biome 
{
    func page(_ index:Ecosystem.Index, pins:[Package.Index: Version]) 
        -> [PageKey: [UInt8]]
    {        
        var page:[PageKey: [UInt8]]
        switch index 
        {
        case .composite(let composite): 
            page = self.page(composite, pins: pins)
        case .article(_): 
            page = [:]
        case .module(let module): 
            page = [:]
        case .package(_):
            page = [:]
        }
        
        return page 
    }
    private 
    func page(_ module:Module.Index, pins:[Package.Index: Version]) 
        -> [PageKey: [UInt8]]
    {
        [:]
    }
    private 
    func page(_ composite:Symbol.Composite, pins:[Package.Index: Version]) 
        -> [PageKey: [UInt8]]
    {
        //  up to three pinned packages involved for a composite: 
        //  1. host package (optional)
        //  2. base package 
        //  3. culture
        let topics:Topics
        let facts:Symbol.Predicates
        if let host:Symbol.Index = composite.natural 
        {
            facts = self.ecosystem[host.module.package].pinned(pins).facts(host)
            // facts = self.ecosystem.facts(host, at: version)
            topics = self.ecosystem.organize(facts: facts, pins: pins, host: host)
        }
        else 
        {
            // no dynamics for synthesized features
            facts = .init(roles: nil)
            topics = .init()
        }
        
        let pinned:(base:Package.Pinned, culture:Package.Pinned) = 
        (
            base: self.ecosystem[composite.base.module.package].pinned(pins),
            culture: self.ecosystem[composite.culture.package].pinned(pins)
        )
        
        let declaration:Symbol.Declaration = 
            pinned.base.declaration(composite.base)
        let article:Article.Template<[Ecosystem.Index]> = 
            pinned.base.template(composite.base).map(self.ecosystem.expand(link:)) 
        
        let fields:[PageKey: DOM.Template<Ecosystem.Index, [UInt8]>] = 
            self.ecosystem.generateFields(for: composite, 
                declaration: declaration,
                facts: facts)
        
        let cards:DOM.Template<CardKey, [UInt8]>? = 
            self.ecosystem.generateCards(topics)
        
        var excerpts:[Symbol.Composite: DOM.Template<[Ecosystem.Index], [UInt8]>] = [:]
        var uris:[Ecosystem.Index: String] = [:] 
        
        if let cards
        {
            for (key, _):(CardKey, Int) in cards.anchors 
            {
                switch key 
                {
                case .uri(let key):
                    if !uris.keys.contains(key)
                    {
                        uris[key] = self.uri(key, pins: pins).description 
                    }
                case .excerpt(let composite):
                    let excerpt:Article.Template<Link> = 
                        self.ecosystem[composite.base.module.package].pinned(pins)
                            .template(composite.base)
                    if !excerpt.summary.isEmpty
                    {
                        excerpts[composite] = 
                            excerpt.summary.map(self.ecosystem.expand(link:)) 
                    }
                }
            }
        }
        
        self.generateURIs(&uris, for: article.summary,    pins: pins)
        self.generateURIs(&uris, for: article.discussion, pins: pins)
        
        for field:DOM.Template<Ecosystem.Index, [UInt8]> in fields.values 
        {
            self.generateURIs(&uris, for: field, pins: pins)
        }
        for excerpt:DOM.Template<[Ecosystem.Index], [UInt8]> in excerpts.values 
        {
            self.generateURIs(&uris, for: excerpt, pins: pins)
        }
        
        var page:[PageKey: [UInt8]] = fields.mapValues 
        {
            // always populated
            $0.rendered { uris[$0]!.utf8 }
        }
        if !article.summary.isEmpty
        {
            page[.summary] = article.summary.rendered
            {
                self.ecosystem.fill(trace: $0, uris: uris).rendered(as: [UInt8].self)
            }
        }
        if !article.discussion.isEmpty
        {
            page[.discussion] = article.discussion.rendered
            {
                self.ecosystem.fill(trace: $0, uris: uris).rendered(as: [UInt8].self)
            }
        }
        if let cards 
        {
            page[.cards] = cards.rendered 
            {
                switch $0 
                {
                case .uri(let key):
                    return [UInt8].init(uris[key]!.utf8)
                case .excerpt(let composite):
                    return excerpts[composite]?.rendered 
                    {
                        self.ecosystem.fill(trace: $0, uris: uris).rendered(as: [UInt8].self)
                    }
                }
            }
        }
        
        self.fill(&page, 
            pinned: pinned.culture, 
            withAvailableVersions: pinned.culture.package.availableVersions(composite), 
            of: .composite(composite))
        
        return page
    }
    private 
    func fill(_ page:inout [PageKey: [UInt8]], 
        pinned:Package.Pinned, 
        withAvailableVersions versions:Set<Version>, 
        of index:Ecosystem.Index)
    {
        let patches:[MaskedVersion: [Version]] = .init(grouping: versions)
        {
            $0.semantic.map { .patch($0.major, $0.minor, $0.patch) } ?? $0.precise
        }
        let abbreviations:[(display:MaskedVersion, version:Version)] = patches.flatMap 
        {
            $0.value.count == 1 ? [($0.key, $0.value[0])] : $0.value.map { ($0.precise, $0) }
        }.sorted 
        {
            $1.version < $0.version
        }
        
        var display:MaskedVersion?
        let items:[HTML.Element<Never>] = abbreviations.map 
        {
            let link:HTML.Element<Never> 
            if  $0.version == pinned.version
            {
                display = $0.display
                link = .span($0.display.description) { ("class", "current") }
            }
            else 
            {
                let uri:URI = self.uri(index, at: $0.version)
                link = .a($0.display.description) { ("href", uri.description) }
            }
            return .li(link)
        }
        
        let menu:HTML.Element<Never> = .ol(items: items)
        let label:(HTML.Element<Never>, HTML.Element<Never>) = 
        (
            .span(pinned.package.id.title)                         { ("class", "package") },
            .span((display ?? pinned.version.precise).description) { ("class", "version") }
        )
        page[.versions] = menu.rendered(as: [UInt8].self)
        page[.pin] = label.0.rendered(as: [UInt8].self) + label.1.rendered(as: [UInt8].self)
    }
}
extension Biome 
{
    private 
    func generateURIs(_ map:inout [Ecosystem.Index: String], 
        for template:DOM.Template<Ecosystem.Index, [UInt8]>, 
        pins:[Package.Index: Version])
    {
        for (key, _):(Ecosystem.Index, Int) in template.anchors 
            where !map.keys.contains(key)
        {
            map[key] = self.uri(key, pins: pins).description 
        }
    }
    private 
    func generateURIs(_ map:inout [Ecosystem.Index: String], 
        for template:DOM.Template<[Ecosystem.Index], [UInt8]>, 
        pins:[Package.Index: Version])
    {
        for (trace, _):([Ecosystem.Index], Int) in template.anchors 
        {
            for key:Ecosystem.Index in trace 
                where !map.keys.contains(key)
            {
                map[key] = self.uri(key, pins: pins).description 
            }
        }
    }
}
