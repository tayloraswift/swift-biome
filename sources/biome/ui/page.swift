import DOM

public
enum Page 
{
    @frozen public 
    enum Anchor:Hashable, Sendable
    {
        case title 
        case constants 
        
        case navigator
        case kind
        case metropole 
        case colony 
        case summary
        case relationships 
        case availability 
        
        case platforms
        case fragments
        
        case headline
        case introduction
        case discussion
        
        case dynamic
    } 
}

extension Biome 
{
    func page(for index:Ecosystem.Index, at version:Version) 
        -> [Page.Anchor: [UInt8]]
    {
        switch index 
        {
        case .composite(let composite): 
            return self.page(for: composite, at: version)
        case .article(_), .module(_), .package(_):
            return [:]
        }
    }
    func page(for composite:Symbol.Composite, at version:Version) 
        -> [Page.Anchor: [UInt8]]
    {
        let fixed:[Page.Anchor: DOM.Template<Ecosystem.Index, [UInt8]>] = 
            self.ecosystem.generateFixedElements(for: composite, at: version)
        
        var referenced:Set<Ecosystem.Index> = [] 
        for template:DOM.Template<Ecosystem.Index, [UInt8]> in fixed.values 
        {
            for (key, _):(Ecosystem.Index, Int) in template.anchors 
            {
                referenced.insert(key)
            }
        }
        
        let article:Article.Template<Link>? = 
            self.ecosystem.template(for: composite.base, at: version)
        
        if let template:DOM.Template<Link, [UInt8]> = article?.summary
        {
            for (link, _):(Link, Int) in template.anchors 
            {
                if case .resolved(let key, visible: _) = link
                {
                    referenced.insert(key)
                }
            }
        }
        if let template:DOM.Template<Link, [UInt8]> = article?.discussion
        {
            for (link, _):(Link, Int) in template.anchors 
            {
                if case .resolved(let key, visible: _) = link
                {
                    referenced.insert(key)
                }
            }
        }
        
        let uris:[Ecosystem.Index: String.UTF8View] = [:]
        
        var page:[Page.Anchor: [UInt8]] = fixed.mapValues 
        {
            $0.rendered(substituting: uris)
        }
        if let template:DOM.Template<Link, [UInt8]> = article?.summary
        {
            page[.summary] = template.rendered
            {
                _ in nil as String.UTF8View?
            }
        }
        if let template:DOM.Template<Link, [UInt8]> = article?.discussion
        {
            page[.discussion] = template.rendered
            {
                _ in nil as String.UTF8View?
            }
        }
        
        return page
    }
}
