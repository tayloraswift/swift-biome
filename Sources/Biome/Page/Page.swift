import DOM
import HTML
import SymbolGraphs
import URI
import Versions

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
        case consumers
        case culture 
        case dependencies 
        case discussion
        case fragments
        case headline
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
    
    let ecosystem:Ecosystem
    private 
    let pins:Package.Pins 
    
    init(ecosystem:Ecosystem, pins:Package.Pins) 
    {
        self.pins = pins 
        self.ecosystem = ecosystem 
        self.substitutions = [.breadcrumbs: ecosystem.logo]
        self.cache = ([:], [:])
    }
    
    func pin(_ package:Packages.Index) -> Package.Pinned 
    {
        fatalError("unimplemented")
        //self.ecosystem[package].pinned(self.pins)
    }
    func template(_ documentation:DocumentationExtension<Atom<Symbol>>) 
        -> DocumentationExtension<Never>
    {
        fatalError("unimplemented")
        // var documentation:DocumentationNode = documentation
        // while true 
        // {
        //     switch documentation 
        //     {
        //     case .inherits(let origin):
        //         documentation = self.pin(origin.module.package)
        //             .documentation(origin)
            
        //     case .extends(_, with: let template):
        //         return template
        //     }
        // }
    }
}
extension Page 
{
    mutating 
    func generate(for choices:[Composite], uri:URI)
    {
        let segregated:[Module.Index: [Card]] = 
            [Module.Index: [Composite]]
            .init(grouping: choices, by: \.culture)
            .mapValues 
        {
            $0.map 
            {
                .composite($0, self.pin($0.base.nationality).declaration(for: $0.base) ?? .init(fallback: "<unavailable>"))
            }
        }
        self.substitutions.merge(
            self.ecosystem.packages.renderFields(for: choices, uri: uri)) { $1 }
        //self.add(topics: self.ecosystem.packages.render(choices: segregated))
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
    }
    private mutating 
    func generate(for package:Packages.Index, exhibit:Version?) 
    {
        let pinned:Package.Pinned = self.pin(package)
        
        self.add(fields: self.ecosystem.packages.renderFields(for: package, 
            version: pinned.version))
        //self.add(topics: self.ecosystem.packages.render(
        //    modulelist: pinned.package.modules.all))
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
        let pinned:Package.Pinned = self.pin(module.nationality)
        //let topics:Topics = self.organize(
        //    toplevel: pinned.topLevelSymbols(of: module) ?? [],
        //    guides: pinned.topLevelArticles(of: module) ?? [])
        
        self.add(fields: self.ecosystem.packages.renderFields(for: module))
        //self.add(topics: self.ecosystem.packages.render(topics: topics))
        self.add(article: pinned.documentation(for: module) ?? .init())
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
        let pinned:Package.Pinned = self.pin(article.nationality)
        
        self.add(fields: self.ecosystem.packages.renderFields(for: article, 
            excerpt: pinned.metadata(local: article)!))
        self.add(article: pinned.documentation(for: article) ?? .init())
        self.add(availableVersions: pinned.package.allVersions(of: article), 
            currentVersion: exhibit ?? pinned.version,
            of: pinned.package)
        {
            $0.uri(of: article, in: $1)
        }
    }
    private mutating 
    func generate(for composite:Composite, exhibit:Version?) 
    {
        //  up to three pinned packages involved for a composite: 
        //  1. host package (optional)
        //  2. base package 
        //  3. culture
        //let topics:Topics
        let facts:Symbol.Predicates<Symbol.Index>
        if let host:Symbol.Index = composite.atom 
        {
            facts = { fatalError("unimplemented") }() // self.pin(host.module.package).facts(host)
            //topics = self.organize(facts: facts, host: host)
        }
        else 
        {
            // no dynamics for synthesized features
            facts = .init(roles: nil)
            //topics = .init()
        }
        
        let base:Package.Pinned = self.pin(composite.base.nationality)
        let pinned:Package.Pinned = self.pin(composite.nationality)
        
        self.add(fields: self.ecosystem.packages.renderFields(for: composite, 
            declaration: base.declaration(for: composite.base) ?? .init(fallback: "<unavailable>"),
            facts: facts))
        //self.add(topics: self.ecosystem.packages.render(topics: topics))
        self.add(article: self.template(base.documentation(for: composite.base) ?? .init()))
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
    func href(_ index:Ecosystem.Index) -> String.UTF8View
    {
        "href=\"\(self.uri(of: index))\"".utf8
    }
    private mutating 
    func uri(of index:Ecosystem.Index) -> String 
    {
        if let cached:String = self.cache.uris[index] 
        {
            return cached 
        }
        let uri:URI 
        switch index 
        {
        case .composite(let composite):
            uri = self.ecosystem.uri(of: composite, 
                in: self.pin(composite.nationality))
        case .article(let article):
            uri = self.ecosystem.uri(of: article, 
                in: self.pin(article.nationality))
        case .module(let module):
            uri = self.ecosystem.uri(of: module, 
                in: self.pin(module.nationality))
        case .package(let package):
            uri = self.ecosystem.uri(
                of: self.pin(package))
        }
        let string:String = uri.description 
        self.cache.uris[index] = string
        return string
    }
    private mutating 
    func headline(of article:Article.Index) -> [UInt8] 
    {
        if let cached:[UInt8] = self.cache.headlines[article] 
        {
            return cached 
        }
        
        guard let excerpt:Article.Metadata = 
            self.pin(article.nationality).metadata(local: article)
        else 
        {
            fatalError("unimplemented")
        }
        let _utf8:[UInt8] = .init(excerpt.headline.formatted.utf8)
        self.cache.headlines[article] = _utf8
        return _utf8
    }
    
    private mutating 
    func expand(_ link:GlobalLink.Presentation) -> HTML.Element<Never>
    {
        let composites:[Composite]
        var crumbs:[HTML.Element<Never>] = []

        fatalError("unimplemented")
        // switch self.ecosystem.expand(link)
        // {
        // case .package(let package): 
        //     return .code(.a(self.ecosystem[package].name, 
        //         attributes: [.href(self.uri(of: .package(package)))]))
        
        // case .article(let article):
        //     return .cite(.a(.init(escaped: self.headline(of: article)), 
        //         attributes: [.href(self.uri(of: .article(article)))])) 
        
        // case .module(let module, let trace):
        //     composites = trace 
        //     // not `title`!
        //     crumbs.reserveCapacity(2 * trace.count + 1)
        //     crumbs.append(.a(self.ecosystem[module].name, 
        //         attributes: [.href(self.uri(of: .module(module)))]))
        
        // case .composite(let trace): 
        //     composites = trace 
        //     crumbs.reserveCapacity(2 * trace.count - 1)
        // }
        for composite:Composite in composites
        {
            if !crumbs.isEmpty 
            {
                crumbs.append(.init(escaped: "."))
            }
            crumbs.append(.a(self.ecosystem[composite.base].name, 
                attributes: [.href(self.uri(of: .composite(composite)))]))
        }
        return .code(crumbs)
    }
}
extension Page 
{
    mutating 
    func add(article:DocumentationExtension<Never>)
    {
        if !article.card.isEmpty
        {
            self.substitutions[.summary] = article.card.rendered
            {
                self.expand($0).node.rendered(as: [UInt8].self)
            }
        }
        if !article.body.isEmpty
        {
            self.substitutions[.discussion] = article.body.rendered
            {
                self.expand($0).node.rendered(as: [UInt8].self)
            }
        }
    }
    
    private mutating 
    func add(fields:[Key: DOM.Flattened<Ecosystem.Index>])
    {
        self.substitutions.reserveCapacity(self.substitutions.count + fields.count)
        for (key, field):(Key, DOM.Flattened<Ecosystem.Index>) in fields 
        {
            self.substitutions[key] = field.rendered { self.href($0) }
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
            counts[package.tree[version].version.triplet, default: 0] += 1
        }
        let strings:[String] = availableVersions.map
        {
            let precise:PreciseVersion = package.tree[$0].version
            let triplet:MaskedVersion = precise.triplet
            return counts[triplet, default: 1] == 1 ? 
                triplet.description : precise.quadruplet.description
        }
        // need to right-pad the strings, since the version menu is left-aligned 
        let width:Int = strings.lazy.map(\.count).max() ?? 0
        
        var current:String? = nil
        var items:[HTML.Element<Never>] = []
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
                items.append(.li(.span(text), attributes: [.class("current")]))
            }
            else 
            {
                let uri:URI = try uri(self.ecosystem, .init(package, at: version))
                items.append(.li(.a(text, attributes: [.href(uri.description)])))
            }
        }
        
        let menu:HTML.Element<Never> = .ol(items) 
        self.substitutions[.versions] = menu.node.rendered(as: [UInt8].self)
        
        let name:HTML.Element<Never> = .span(package.id.title, attributes: [.class("package")]) 
        if  let current:String 
        {
            let current:HTML.Element<Never> = .span(
                escaped: currentVersion == package.tree.default ? "latest" : current, 
                attributes: [.class("version")]) 
            self.substitutions[.pin] = name.node.rendered(as: [UInt8].self) + 
                current.node.rendered(as: [UInt8].self)
        }
        else 
        {
            self.substitutions[.pin] = name.node.rendered(as: [UInt8].self) 
            
            let snapped:Int = { fatalError("unimplemented") }()
            //    availableVersions.lastIndex { $0 < currentVersion } ?? 
            //    availableVersions.startIndex
            let uri:URI = try uri(self.ecosystem, 
                .init(package, at: availableVersions[snapped]))
            
            let notice:HTML.Element<Never> = .div(.div(.p()),
                .div(
                    .p(
                        .init(escaped: "This symbol does not exist in the requested version of "),
                        name,
                        .init(escaped: ".")),
                    .p(
                        .init(escaped: "The documentation from version "),
                        .a(strings[snapped - availableVersions.startIndex], 
                            attributes: [.href(uri.description), .class("version")]),
                        .init(escaped: " is shown below."))), 
                attributes: [.class("notice extinct")])
            
            self.substitutions[.notices] = notice.node.rendered(as: [UInt8].self) 
        }
    }
    mutating 
    func add<Constants>(scriptConstants:Constants) 
        where Constants:Sequence, Constants.Element == Packages.Index
    {
        // package name is alphanumeric, we should enforce this in 
        // `Package.ID`, otherwise this could be a security hole
        let source:String =
        """
        searchIndices = [\(scriptConstants.map 
        { 
            "'\(self.ecosystem.uriOfSearchIndex(for: $0))'"
        }.joined(separator: ","))];
        """
        self.substitutions[.constants] = [UInt8].init(source.utf8)
    }
}
