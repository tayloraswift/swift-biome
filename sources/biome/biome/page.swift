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
    func generatePage(for selection:Ecosystem.Selection, pins:[Package.Index: Version]) 
        -> [PageKey: [UInt8]]
    {
        switch selection
        {        
        case .index(let index):
            return self.generatePage(for: index, pins: pins)
        
        case .composites(let all):
            fatalError("unimplemented")
        }
    }
    
    private 
    func generatePage(for index:Ecosystem.Index, pins:[Package.Index: Version]) 
        -> [PageKey: [UInt8]]
    {
        var page:[PageKey: [UInt8]]
        switch index 
        {
        case .composite(let composite): 
            page = self.generatePage(for: composite, pins: pins)
        case .article(let article): 
            page = self.generatePage(for: article, pins: pins)
        case .module(let module): 
            page = self.generatePage(for: module, pins: pins)
        case .package(_):
            page = [:]
        }
        self.addScriptConstants(to: &page)
        return page 
    }
    private 
    func generatePage(for module:Module.Index, pins:[Package.Index: Version]) 
        -> [PageKey: [UInt8]]
    {
        let pinned:Package.Pinned = self.ecosystem[module.package].pinned(pins)
        let topics:Topics = self.ecosystem.organize(toplevel: pinned.toplevel(module), 
            pins: pins)
        
        var page:[PageKey: [UInt8]] = self.generatePage(
            article: pinned.template(module).map(self.ecosystem.expand(link:)), 
            fields: self.ecosystem.generateFields(for: module), 
            cards: self.ecosystem.generateCards(topics), 
            pins: pins)
        
        self.addAvailableVersions(to: &page, 
            versions: pinned.package.allVersions(of: module), 
            pinned: pinned, 
            index: .module(module))
        
        return page
    }
    private 
    func generatePage(for composite:Symbol.Composite, pins:[Package.Index: Version]) 
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
        
        var page:[PageKey: [UInt8]] = self.generatePage(
            article: pinned.base.template(composite.base)
                .map(self.ecosystem.expand(link:)), 
            fields: self.ecosystem.generateFields(for: composite, 
                declaration: declaration,
                facts: facts), 
            cards: self.ecosystem.generateCards(topics), 
            pins: pins)
        
        self.addAvailableVersions(to: &page, 
            versions: pinned.culture.package.allVersions(of: composite), 
            pinned: pinned.culture, 
            index: .composite(composite))
        
        return page
    }
    private 
    func generatePage(for article:Article.Index, pins:[Package.Index: Version]) 
        -> [PageKey: [UInt8]]
    {
        let pinned:Package.Pinned = self.ecosystem[article.module.package].pinned(pins)
        let template:Article.Template<[Ecosystem.Index]> = 
            pinned.template(article).map(self.ecosystem.expand(link:))
        
        var uris:[Ecosystem.Index: String] = [:] 
        
        self.generateURIs              (&uris, for: template.summary,    pins: pins)
        self.generateURIs              (&uris, for: template.discussion, pins: pins)
        // cannot use `addRenderedSummaryAndDiscussion`, because we want the 
        // summary to appear under the fold
        var page:[PageKey: [UInt8]] = 
        [
            .introduction: template.summary.rendered
            {
                self.ecosystem.fill(trace: $0, uris: uris).rendered(as: [UInt8].self)
            }, 
            .discussion: template.discussion.rendered
            {
                self.ecosystem.fill(trace: $0, uris: uris).rendered(as: [UInt8].self)
            }
        ]
        self.addAvailableVersions(to: &page, 
            versions: pinned.package.allVersions(of: article), 
            pinned: pinned, 
            index: .article(article))
        return page
    }
    
    private 
    func generatePage(
        article:Article.Template<[Ecosystem.Index]>,
        fields:[PageKey: DOM.Template<Ecosystem.Index, [UInt8]>], 
        cards:DOM.Template<CardKey, [UInt8]>?, 
        pins:[Package.Index: Version])
        -> [PageKey: [UInt8]]
    {
        var uris:[Ecosystem.Index: String] = [:] 

        let excerpts:[Symbol.Composite: DOM.Template<[Ecosystem.Index], [UInt8]>] = 
            self.generateExcerpts(uris: &uris, for: cards,              pins: pins)
        self.generateURIs              (&uris, for: article.summary,    pins: pins)
        self.generateURIs              (&uris, for: article.discussion, pins: pins)
        
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
        self.addRenderedSummaryAndDiscussion(to: &page, 
            template: article, 
            uris: uris)
        self.addRenderedCards(to: &page, 
            cards: cards, 
            excerpts: excerpts, 
            uris: uris)
        return page
    }
    private 
    func addRenderedSummaryAndDiscussion(to page:inout [PageKey: [UInt8]], 
        template:Article.Template<[Ecosystem.Index]>, 
        uris:[Ecosystem.Index: String])
    {
        if !template.summary.isEmpty
        {
            page[.summary] = template.summary.rendered
            {
                self.ecosystem.fill(trace: $0, uris: uris).rendered(as: [UInt8].self)
            }
        }
        if !template.discussion.isEmpty
        {
            page[.discussion] = template.discussion.rendered
            {
                self.ecosystem.fill(trace: $0, uris: uris).rendered(as: [UInt8].self)
            }
        }
    }
    private 
    func addRenderedCards(to page:inout [PageKey: [UInt8]], 
        cards:DOM.Template<CardKey, [UInt8]>?,
        excerpts:[Symbol.Composite: DOM.Template<[Ecosystem.Index], [UInt8]>], 
        uris:[Ecosystem.Index: String])
    {
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
    }
    private 
    func addAvailableVersions(to page:inout [PageKey: [UInt8]], 
        versions:[Version], 
        pinned:Package.Pinned, 
        index:Ecosystem.Index)
    {
        var counts:[MaskedVersion: Int] = [:]
        for version:Version in versions 
        {
            counts[pinned.package.versions[version].triplet, default: 0] += 1
        }
        
        func display(_ version:Version) -> MaskedVersion
        {
            let precise:PreciseVersion = pinned.package.versions[version]
            let triplet:MaskedVersion = precise.triplet
            if case 1? = counts[triplet] 
            {
                return triplet
            }
            else 
            {
                return precise.quadruplet
            }
        }
        
        let items:[HTML.Element<Never>] = versions.reversed().map 
        {
            let display:MaskedVersion = display($0)
            let link:HTML.Element<Never> 
            if  $0 == pinned.version
            {
                link = .span(display.description) { ("class", "current") }
            }
            else 
            {
                let uri:URI = self.uri(of: index, at: $0)
                link = .a(display.description) { ("href", uri.description) }
            }
            return .li(link)
        }
        
        let menu:HTML.Element<Never> = .ol(items: items)
        let label:(HTML.Element<Never>, HTML.Element<Never>) = 
        (
            .span(pinned.package.id.title)              { ("class", "package") },
            .span(display(pinned.version).description)  { ("class", "version") }
        )
        page[.versions] = menu.rendered(as: [UInt8].self)
        page[.pin] = label.0.rendered(as: [UInt8].self) + label.1.rendered(as: [UInt8].self)
    }
    private  
    func addScriptConstants(to page:inout [PageKey: [UInt8]]) 
    {
        // package name is alphanumeric, we should enforce this in 
        // `Package.ID`, otherwise this could be a security hole
        let uris:[String] = self.ecosystem.indices.keys.map 
        { 
            "'/\(self.prefixes.lunr)/\($0.string)/types'" 
        }
        let source:String =
        """
        searchIndices = [\(uris.joined(separator: ","))];
        """
        page[.constants] = [UInt8].init(source.utf8)
    }
}
extension Biome 
{    
    private 
    func generateURIs(_ uris:inout [Ecosystem.Index: String], 
        for template:DOM.Template<Ecosystem.Index, [UInt8]>, 
        pins:[Package.Index: Version])
    {
        for (key, _):(Ecosystem.Index, Int) in template.anchors 
            where !uris.keys.contains(key)
        {
            uris[key] = self.uri(of: key, pins: pins).description 
        }
    }
    private 
    func generateURIs(_ uris:inout [Ecosystem.Index: String], 
        for template:DOM.Template<[Ecosystem.Index], [UInt8]>, 
        pins:[Package.Index: Version])
    {
        for (trace, _):([Ecosystem.Index], Int) in template.anchors 
        {
            for key:Ecosystem.Index in trace 
                where !uris.keys.contains(key)
            {
                uris[key] = self.uri(of: key, pins: pins).description 
            }
        }
    }
    
    private 
    func generateExcerpts(uris:inout [Ecosystem.Index: String], 
        for cards:DOM.Template<CardKey, [UInt8]>?, 
        pins:[Package.Index: Version])
        -> [Symbol.Composite: DOM.Template<[Ecosystem.Index], [UInt8]>]
    {
        guard let cards
        else 
        {
            return [:]
        }
        var excerpts:[Symbol.Composite: DOM.Template<[Ecosystem.Index], [UInt8]>] = [:]
        for (key, _):(CardKey, Int) in cards.anchors 
        {
            switch key 
            {
            case .uri(let key):
                if !uris.keys.contains(key)
                {
                    uris[key] = self.uri(of: key, pins: pins).description 
                }
            case .excerpt(let composite):
                let excerpt:Article.Template<Ecosystem.Link> = 
                    self.ecosystem[composite.base.module.package].pinned(pins)
                        .template(composite.base)
                if !excerpt.summary.isEmpty
                {
                    excerpts[composite] = 
                        excerpt.summary.map(self.ecosystem.expand(link:)) 
                }
            }
        }
        return excerpts
    }
}
