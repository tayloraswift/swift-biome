import DOM

public
enum Page 
{
    @frozen public 
    enum Anchor:Hashable, Sendable
    {
        case title 
        case constants 
        
        case availability 
        case culture 
        case discussion
        case dynamic
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
}

extension Biome 
{
    func page(_ index:Ecosystem.Index, pins:[Package.Index: Version]) 
        -> [Page.Anchor: [UInt8]]
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
        -> [Page.Anchor: [UInt8]]
    {
        let article:Article.Template<[Ecosystem.Index]>? = 
            self.ecosystem.loadArticle(composite, pins: pins)
        let fixed:[Page.Anchor: DOM.Template<Ecosystem.Index, [UInt8]>] = 
            self.ecosystem.generateFixedElements(composite, pins: pins)
        
        var uris:[Ecosystem.Index: String] = [:] 
        for template:DOM.Template<Ecosystem.Index, [UInt8]> in fixed.values 
        {
            self.generateURIs(&uris, for: template, pins: pins)
        }
        if let template:DOM.Template<[Ecosystem.Index], [UInt8]> = article?.summary
        {
            self.generateURIs(&uris, for: template, pins: pins)
        }
        if let template:DOM.Template<[Ecosystem.Index], [UInt8]> = article?.discussion
        {
            self.generateURIs(&uris, for: template, pins: pins)
        }
        
        var page:[Page.Anchor: [UInt8]] = fixed.mapValues 
        {
            // always populated
            $0.rendered { uris[$0]!.utf8 }
        }
        if let template:DOM.Template<[Ecosystem.Index], [UInt8]> = article?.summary
        {
            page[.summary] = template.rendered
            {
                self.ecosystem.fill(trace: $0, uris: uris).rendered(as: [UInt8].self)
            }
        }
        if let template:DOM.Template<[Ecosystem.Index], [UInt8]> = article?.discussion
        {
            page[.discussion] = template.rendered
            {
                self.ecosystem.fill(trace: $0, uris: uris).rendered(as: [UInt8].self)
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
