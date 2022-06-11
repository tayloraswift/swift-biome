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
        
        var uris:[Ecosystem.Index: String.UTF8View] = [:] 
        for template:DOM.Template<Ecosystem.Index, [UInt8]> in fixed.values 
        {
            for (key, _):(Ecosystem.Index, Int) in template.anchors 
                where !uris.keys.contains(key)
            {
                // let uri:URI = self.location(of: key)
                // uris[key] = uri.description
            }
        }
        
        if  let template:Article.Template<Link> = 
            self.ecosystem.template(for: composite.base, at: version)
        {
        }
        
        return fixed.mapValues 
        {
            $0.rendered(as: [UInt8].self, substituting: uris)
        }
    }
}
