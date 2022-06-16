import DOM

@frozen public 
enum PageKey:Hashable, Sendable
{
    case title 
    case constants 
    
    case availability 
    case base
    case cards
    case culture 
    case discussion
    case fragments
    case headline
    case introduction
    case kind
    case namespace 
    case navigator
    case platforms
    case relationships 
    case summary
} 
enum CardKey:Hashable, Sendable 
{
    case uri(Symbol.Composite)
    case excerpt(Symbol.Composite)
}

extension Biome 
{
    func page(_ index:Ecosystem.Index, pins:[Package.Index: Version]) 
        -> [PageKey: [UInt8]]
    {
        switch index 
        {
        case .composite(let composite): 
            return self.page(composite, pins: pins)
        case .article(_), .module(_), .package(_):
            return [:]
        }
    }
    func page(_ composite:Symbol.Composite, pins:[Package.Index: Version]) 
        -> [PageKey: [UInt8]]
    {
        let article:Article.Template<[Ecosystem.Index]> = 
            self.ecosystem.generateArticle(composite, pins: pins)
        let fields:[PageKey: DOM.Template<Ecosystem.Index, [UInt8]>] = 
            self.ecosystem.generateFields(composite, pins: pins)
        let cards:DOM.Template<CardKey, [UInt8]>? = 
            self.ecosystem.generateCards(composite, pins: pins)
        
        var excerpts:[Symbol.Composite: DOM.Template<[Ecosystem.Index], [UInt8]>] = [:]
        var uris:[Ecosystem.Index: String] = [:] 
        
        if let cards
        {
            for (key, _):(CardKey, Int) in cards.anchors 
            {
                switch key 
                {
                case .uri(let composite):
                    let key:Ecosystem.Index = .composite(composite)
                    if !uris.keys.contains(key)
                    {
                        uris[key] = self.uri(key, pins: pins).description 
                    }
                case .excerpt(let composite):
                    if  let excerpt:DOM.Template<[Ecosystem.Index], [UInt8]> = 
                        self.ecosystem.generateExcerpt(composite, pins: pins)
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
                case .uri(let composite):
                    return [UInt8].init(uris[.composite(composite)]!.utf8)
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
