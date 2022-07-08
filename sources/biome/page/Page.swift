import HTML

public 
struct Page 
{
    @frozen public 
    enum Key:Hashable, Sendable
    {
        case title 
        case constants 
        
        case availability 
        case base
        case breadcrumbs
        case culture 
        case discussion
        case fragments
        case headline
        case introduction
        case kind
        case namespace 
        case notes 
        case notices
        case pin 
        case platforms
        case summary
        case topics
        case versions
    } 
    
    private(set) 
    var substitutions:[Key: [UInt8]]
    private
    var cache:
    (
        headlines:[Article.Index: [UInt8]], 
        uris:[Ecosystem.Index: String]
    )
    private 
    let era:Ecosystem.Pinned 
        
    private 
    var ecosystem:Ecosystem 
    {
        _read 
        {
            yield self.era.ecosystem
        }
    }
    init(_ era:Ecosystem.Pinned, logo:[UInt8]) 
    {
        self.substitutions = [.breadcrumbs: logo]
        self.cache = ([:], [:])
        self.era = era 
    }
}
extension Page 
{
    mutating 
    func generate(for choices:[Symbol.Composite], uri:URI)
    {
        let segregated:[Module.Index: [Symbol.Card]] = 
            [Module.Index: [Symbol.Composite]]
            .init(grouping: choices, by: \.culture)
            .mapValues 
        {
            $0.map 
            {
                ($0, self.era.pin($0.base.module.package).declaration($0.base))
            }
        }
        self.substitutions.merge(
            self.ecosystem.renderFields(for: choices, uri: uri)) { $1 }
        self.add(topics: self.ecosystem.render(choices: segregated))
        self.add(scriptConstants: era.ecosystem.indices.values)
    }
    mutating 
    func generate(for index:Ecosystem.Index, exhibit:Version?)
    {
        switch index 
        {
        case .composite(let composite): 
            self.generate(for: composite, exhibit: exhibit)
        case .article(let article): 
            self.generate(for: article, exhibit: exhibit)
        case .module(let module): 
            self.generate(for: module, exhibit: exhibit)
        case .package(let package):
            self.generate(for: package, exhibit: exhibit)
        }
        self.add(scriptConstants: era.ecosystem.indices.values)
    }
    private mutating 
    func generate(for package:Package.Index, exhibit:Version?) 
    {
        let pinned:Package.Pinned = self.era.pin(package)
        
        self.add(fields: self.ecosystem.renderFields(for: package))
        self.add(topics: self.ecosystem.render(modulelist: pinned.package.modules.all))
        self.add(availableVersions: pinned.package.allVersions(), 
            currentVersion: exhibit ?? pinned.version,
            of: pinned.package)
        {
            $0.uri(of: $1)
        }
    }
    private mutating 
    func generate(for module:Module.Index, exhibit:Version?) 
    {
        let pinned:Package.Pinned = self.era.pin(module.package)
        let topics:Topics = self.era.organize(toplevel: pinned.toplevel(module))
        
        self.add(fields: self.ecosystem.renderFields(for: module))
        self.add(topics: self.ecosystem.render(topics: topics))
        self.add(article: pinned.template(module))
        self.add(availableVersions: pinned.package.allVersions(of: module), 
            currentVersion: exhibit ?? pinned.version,
            of: pinned.package)
        {
            $0.uri(of: module, in: $1)
        }
    }
    private mutating
    func generate(for article:Article.Index, exhibit:Version?)
    {
        let pinned:Package.Pinned = self.era.pin(article.module.package)
        
        self.add(fields: self.ecosystem.renderFields(for: article, 
            headline: pinned.headline(article)))
        self.add(article: pinned.template(article))
        self.add(availableVersions: pinned.package.allVersions(of: article), 
            currentVersion: exhibit ?? pinned.version,
            of: pinned.package)
        {
            $0.uri(of: article, in: $1)
        }
    }
    private mutating 
    func generate(for composite:Symbol.Composite, exhibit:Version?) 
    {
        //  up to three pinned packages involved for a composite: 
        //  1. host package (optional)
        //  2. base package 
        //  3. culture
        let topics:Topics
        let facts:Symbol.Predicates
        if let host:Symbol.Index = composite.natural 
        {
            facts = self.era.pin(host.module.package).facts(host)
            topics = self.era.organize(facts: facts, host: host)
        }
        else 
        {
            // no dynamics for synthesized features
            facts = .init(roles: nil)
            topics = .init()
        }
        
        let base:Package.Pinned = self.era.pin(composite.base.module.package)
        let pinned:Package.Pinned = self.era.pin(composite.culture.package)
        
        self.add(fields: self.ecosystem.renderFields(for: composite, 
            declaration: base.declaration(composite.base),
            facts: facts))
        self.add(topics: self.ecosystem.render(topics: topics))
        self.add(article: base.template(composite.base))
        self.add(availableVersions: pinned.package.allVersions(of: composite), 
            currentVersion: exhibit ?? pinned.version,
            of: pinned.package)
        {
            $0.uri(of: composite, in: $1)
        }
    }
}
extension Page 
{
    private mutating 
    func uri(of index:Ecosystem.Index) -> String 
    {
        self.era.uri(of: index, cache: &self.cache.uris)
    }
    private mutating 
    func headline(of article:Article.Index) -> [UInt8] 
    {
        self.era.headline(of: article, cache: &self.cache.headlines)
    }
    
    private mutating 
    func expand(_ link:Ecosystem.Link) -> HTML.Element<Never>
    {
        let composites:[Symbol.Composite]
        var crumbs:[HTML.Element<Never>] = []
        switch self.ecosystem.expand(link)
        {
        case .package(let package): 
            let text:String = self.ecosystem[package].name
            let uri:String = self.uri(of: .package(package))
            return .code(.a(text) { ("href", uri) })
        
        case .article(let article):
            let utf8:[UInt8] = self.headline(of: article)
            let uri:String = self.uri(of: .article(article))
            return .cite(.a(.bytes(utf8: utf8)) { ("href", uri) }) 
        
        case .module(let module, let trace):
            composites = trace 
            // not `title`!
            let text:String = self.ecosystem[module].name
            let uri:String = self.uri(of: .module(module))
            crumbs.reserveCapacity(2 * trace.count + 1)
            crumbs.append(.a(text) { ("href", uri) })
        
        case .composite(let trace): 
            composites = trace 
            crumbs.reserveCapacity(2 * trace.count - 1)
        }
        for composite:Symbol.Composite in composites
        {
            if !crumbs.isEmpty 
            {
                crumbs.append(.text(escaped: "."))
            }
            let text:String = self.ecosystem[composite.base].name
            let uri:String = self.uri(of: .composite(composite))
            crumbs.append(.a(text) { ("href", uri) })
        }
        return .code(crumbs)
    }
    
    private mutating 
    func add(fields:[Key: DOM.Template<Ecosystem.Index, [UInt8]>])
    {
        self.substitutions.reserveCapacity(self.substitutions.count + fields.count)
        for (key, field):(Key, DOM.Template<Ecosystem.Index, [UInt8]>) in fields 
        {
            self.substitutions[key] = field.rendered { self.uri(of: $0).utf8 }
        }
    }
    private mutating 
    func add(article:Article.Template<Ecosystem.Link>)
    {
        if !article.summary.isEmpty
        {
            self.substitutions[.summary] = article.summary.rendered
            {
                self.expand($0).rendered(as: [UInt8].self)
            }
        }
        if !article.discussion.isEmpty
        {
            self.substitutions[.discussion] = article.discussion.rendered
            {
                self.expand($0).rendered(as: [UInt8].self)
            }
        }
    }
    private mutating 
    func add(topics:DOM.Template<Topics.Key, [UInt8]>?)
    {
        guard let topics:DOM.Template<Topics.Key, [UInt8]>
        else 
        {
            return 
        }
        self.substitutions[.topics] = topics.rendered 
        {
            switch $0 
            {
            case .uri(let index):
                return [UInt8].init(self.uri(of: index).utf8)
            case .excerpt(let composite):
                return self.era.pin(composite.base.module.package)
                    .template(composite.base)
                    .summary.rendered 
                {
                    self.expand($0).rendered(as: [UInt8].self)
                }
            }
        }
    }
    // this takes separate ``Version`` and ``Package`` arguments instead of a 
    // combined `Package.Pinned` argument to avoid confusion
    private mutating 
    func add(availableVersions:[Version], 
        currentVersion:Version, 
        of package:Package, 
        _ uri:(Ecosystem, Package.Pinned) throws -> URI) rethrows 
    {
        var counts:[MaskedVersion: Int] = [:]
        for version:Version in availableVersions 
        {
            counts[package.versions.precise(version).triplet, default: 0] += 1
        }
        let strings:[String] = availableVersions.map
        {
            let precise:PreciseVersion = package.versions.precise($0)
            let triplet:MaskedVersion = precise.triplet
            return counts[triplet, default: 1] == 1 ? 
                triplet.description : precise.quadruplet.description
        }
        // need to right-pad the strings, since the version menu is left-aligned 
        let width:Int = strings.lazy.map(\.count).max() ?? 0
        
        var current:String? = nil
        var items:[HTML.StaticElement] = []
            items.reserveCapacity(availableVersions.count)
        for (version, text):(Version, String) in 
            zip(availableVersions, strings).reversed()
        {
            let fill:Int = width - text.count
            let text:String = fill > 0 ? 
                text + repeatElement(" ", count: fill) : text
            
            if  version == currentVersion
            {
                current = text 
                items.append(.li(.span(text)) { ("class", "current") })
            }
            else 
            {
                let uri:URI = try uri(self.ecosystem, .init(package, at: version))
                items.append(.li(.a(text) { ("href", uri.description) }))
            }
        }
        
        let menu:HTML.StaticElement = .ol(items: items) 
        self.substitutions[.versions] = menu.rendered(as: [UInt8].self)
        
        let name:HTML.StaticElement = .span(package.id.title) 
        { 
            ("class", "package") 
        }
        if  let current:String 
        {
            let current:HTML.StaticElement = .span(current) 
            { 
                ("class", "version") 
            }
            self.substitutions[.pin] = name.rendered(as: [UInt8].self) + 
                current.rendered(as: [UInt8].self)
        }
        else 
        {
            self.substitutions[.pin] = name.rendered(as: [UInt8].self) 
            
            let snapped:Int = availableVersions.lastIndex { $0 < currentVersion } ?? 
                availableVersions.startIndex
            let uri:URI = try uri(self.ecosystem, 
                .init(package, at: availableVersions[snapped]))
            
            let notice:HTML.StaticElement = HTML.StaticElement[.div]
            {
                ("class", "notice extinct")
            }
            content: 
            {
                HTML.StaticElement[.div]
                {
                    HTML.StaticElement.p([])
                }
                HTML.StaticElement[.div]
                {
                    HTML.StaticElement[.p]
                    {
                        "This symbol does not exist in the requested version of "
                        name
                        "."
                    }
                    HTML.StaticElement[.p]
                    {
                        "The documentation from version "
                        HTML.StaticElement.a(strings[snapped - availableVersions.startIndex])
                        {
                            ("href",    uri.description)
                            ("class",   "version")
                        }
                        " is shown below."
                    }
                }
            }
            
            self.substitutions[.notices] = notice.rendered(as: [UInt8].self) 
        }
    }
    private mutating 
    func add<Constants>(scriptConstants:Constants) 
        where Constants:Sequence, Constants.Element == Package.Index
    {
        // package name is alphanumeric, we should enforce this in 
        // `Package.ID`, otherwise this could be a security hole
        let source:String =
        """
        searchIndices = [\(scriptConstants.map 
        { 
            "'\(self.ecosystem.uri(of: .searchIndex($0)))'"
        }.joined(separator: ","))];
        """
        self.substitutions[.constants] = [UInt8].init(source.utf8)
    }
}
