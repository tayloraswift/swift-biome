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
        let culture:Package = self.ecosystem[index.culture]
        let precise:Set<Version>
        
        var page:[PageKey: [UInt8]]
        switch index 
        {
        case .composite(let composite): 
            precise = culture.availableVersions(composite)
            page = self.page(composite, pins: pins)
        case .article(_): 
            precise = []
            page = [:]
        case .module(let module): 
            precise = culture.availableVersions(module)
            page = [:]
        case .package(_):
            precise = culture.availableVersions()
            page = [:]
        }
        
        let current:Version = pins[culture.index] ?? culture.latest
        let patches:[Version: [Version]] = .init(grouping: precise, by: \.editionless)
        let abbreviations:[(display:Version, precise:Version)] = patches.flatMap 
        {
            $0.value.count == 1 ? [(display: $0.key, precise: $0.value[0])] :
                $0.value.map    {  (display: $0,     precise: $0)  }
        }.sorted 
        {
            $1.precise < $0.precise
        }
        
        var display:Version = current 
        let versions:[HTML.Element<Never>] = abbreviations.map 
        {
            let link:HTML.Element<Never> 
            if  $0.precise == current
            {
                display = $0.display
                link = .span($0.display.description) { ("class", "current") }
            }
            else 
            {
                let uri:URI = self.uri(index, at: $0.precise)
                link = .a($0.display.description) { ("href", uri.description) }
            }
            return .li(link)
        }
        
        let menu:HTML.Element<Never> = .ol(items: versions)
        let label:(HTML.Element<Never>, HTML.Element<Never>) = 
        (
            .span(culture.id.title)    { ("class", "package") },
            .span(display.description) { ("class", "version") }
        )
        page[.versions] = menu.rendered(as: [UInt8].self)
        page[.pin] = label.0.rendered(as: [UInt8].self) + label.1.rendered(as: [UInt8].self)
        
        return page 
    }
    private 
    func page(_ composite:Symbol.Composite, pins:[Package.Index: Version]) 
        -> [PageKey: [UInt8]]
    {
        let topics:Topics
        let facts:Symbol.Predicates
        
        if let host:Symbol.Index = composite.natural 
        {
            let version:Version = pins[host.module.package] ?? 
                self.ecosystem[host.module.package].latest
            facts = self.ecosystem.facts(host, at: version)
            topics = self.ecosystem.organize(facts: facts, pins: pins, host: host)
        }
        else 
        {
            // no dynamics for synthesized features
            facts = .init(roles: nil)
            topics = .init()
        }
        
        let declaration:Symbol.Declaration = 
            self.ecosystem.baseDeclaration(composite, pins: pins) 
        let article:Article.Template<[Ecosystem.Index]> = 
            self.ecosystem.baseTemplate(composite, pins: pins)
                .map(self.ecosystem.expand(link:)) 
        
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
                    if  let excerpt:DOM.Template<[Ecosystem.Index], [UInt8]> = 
                        self.ecosystem.generateExcerpt(for: composite, pins: pins)
                    {
                        excerpts[composite] = excerpt
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
        return page
    }
    
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
