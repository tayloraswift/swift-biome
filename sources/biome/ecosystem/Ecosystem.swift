/// an ecosystem is a subset of a biome containing packages that are relevant 
/// (in some user-defined way) to some task. 
/// 
/// ecosystem views are mainly useful for providing an immutable context for 
/// accessing foreign packages.
@usableFromInline
struct Ecosystem 
{    
    @usableFromInline 
    enum Index:Hashable, Sendable
    {
        case package(Package.Index)
        case module(Module.Index)
        case article(Article.Index)
        case composite(Symbol.Composite)
        
        static 
        func symbol(_ natural:Symbol.Index) -> Self 
        {
            .composite(.init(natural: natural))
        }
    }
    
    struct Link:Hashable, Sendable
    {
        enum Expansion:Hashable, Sendable 
        {
            case package(Package.Index)
            case article(Article.Index)
            case module(Module.Index, [Symbol.Composite] = [])
            case composite           ([Symbol.Composite])
        }
        
        let target:Index 
        let visible:Int
        
        init(_ target:Index, visible:Int)
        {
            self.target = target 
            self.visible = visible
        }
    }
    
    /* func describe(_ error:LinkResolutionError) -> String 
    {
        switch error 
        {
        case .none(let expression): 
            return "symbol link '\(expression)' matches no known symbols"
        case .many(let expression, let possibilities):
            return 
                """
                symbol link '\(expression)' matches multiple symbols:
                \(possibilities.enumerated().map 
                {
                    let symbol:Symbol = self[$0.1.base]
                    if let host:Symbol.Index = $0.1.host 
                    {
                        return "\($0.0). \(self[host].path).\(symbol.name) (\(symbol.id.string))"
                    }
                    else 
                    {
                        return "\($0.0). \(symbol.path) (\(symbol.id.string))"
                    }
                }.joined(separator: "\n"))
                """
        }
    } */
    
    let root:
    (    
        master:String,
        article:String,
        sitemap:String,
        searchIndex:String
    )
    private(set)
    var packages:[Package], 
        indices:[Package.ID: Package.Index]
        
    func pinned(_ pins:[Package.Index: Version]) -> Pinned 
    {
        .init(self, pins: pins)
    }

    init(roots:[Root: String])
    {
        self.root = 
        (
            master:         roots[.master,      default: "reference"],
            article:        roots[.article,     default: "learn"],
            sitemap:        roots[.sitemap,     default: "sitemaps"],
            searchIndex:   roots[.searchIndex,  default: "lunr"]
        )
        self.indices = [:]
        self.packages = []
    }
    
    subscript(package:Package.ID) -> Package?
    {
        self.indices[package].map { self[$0] }
    } 
    subscript(package:Package.Index) -> Package
    {
        _read 
        {
            yield  self.packages[package.offset]
        }
        _modify 
        {
            yield &self.packages[package.offset]
        }
    } 
    subscript(module:Module.Index) -> Module
    {
        _read 
        {
            yield self.packages[       module.package.offset][local: module]
        }
    } 
    subscript(symbol:Symbol.Index) -> Symbol
    {
        _read 
        {
            yield self.packages[symbol.module.package.offset][local: symbol]
        }
    } 
    subscript(article:Article.Index) -> Article
    {
        _read 
        {
            yield self.packages[article.module.package.offset][local: article]
        }
    } 
    
    var standardLibrary:Set<Module.Index>
    {
        if let swift:Package = self[.swift]
        {
            return .init(swift.modules.indices.values)
        }
        else 
        {
            // must register standard library before any other packages 
            fatalError("first package must be the swift standard library")
        }
    }
    
    @usableFromInline
    func uri(of resolution:Resolution) 
        -> (exact:URI, canonical:URI?) 
    {
        switch resolution 
        {        
        case .index(let index, let pins, exhibit: let exhibit):
            return self.uri(of: index, pins: pins, exhibit: exhibit)
            
        case .choices(let choices, let pins):
            return (self.uri(of: choices, pins: pins), nil)
        
        case .searchIndex(let package): 
            return (self.uriOfSearchIndex(for: package), nil)
        
        case .sitemap(let package): 
            return (self.uriOfSiteMap(for: package), nil)
        }
    }
    private 
    func uri(of index:Index, pins:[Package.Index: Version], exhibit:Version?) 
        -> (exact:URI, canonical:URI?) 
    {
        let uri:URI
        let pinned:Package.Pinned
        switch index 
        {
        case .composite(let composite):
            pinned = self[composite.culture.package].pinned(pins, exhibit: exhibit)
            uri = self.uri(of: composite, in: pinned)
            guard composite.isNatural 
            else 
            {
                // if this is a synthetic feature, set the canonical page to 
                // its generic base (which may be in a completely different package)
                let canonical:URI = self.uri(of: .init(natural: composite.base), 
                    in: self[composite.base.module.package].pinned())
                return (exact: uri, canonical: canonical)
            }
        
        case .article(let article):
            pinned = self[article.module.package].pinned(pins, exhibit: exhibit)
            uri = self.uri(of: article, in: pinned)
            
        case .module(let module):
            pinned = self[module.package].pinned(pins, exhibit: exhibit)
            uri = self.uri(of: module, in: pinned)
        
        case .package(let package):
            pinned = self[package].pinned(pins, exhibit: exhibit)
            uri = self.uri(of: pinned)
        }
        
        if pinned.version == pinned.package.versions.latest 
        {
            return (exact: uri, nil)
        }
        else
        {
            // if this is an old version, set the canonical version to 
            // the latest version 
            return (exact: uri, self.uri(of: index, in: pinned.package.pinned()))
        }
    }
    private 
    func uri(of index:Index, in pinned:Package.Pinned) -> URI 
    {
        switch index 
        {
        case .composite(let composite):
            return self.uri(of: composite, in: pinned)
        case .article(let article):
            return self.uri(of: article, in: pinned)
        case .module(let module):
            return self.uri(of: module, in: pinned)
        case .package(_):
            return self.uri(of: pinned)
        }
    }

    func uri(of pinned:Package.Pinned) -> URI
    {
        .init(root: self.root.master, path: pinned.path())
    }
    func uri(of module:Module.Index, in pinned:Package.Pinned) -> URI
    {
        .init(root: self.root.master, path: pinned.path(to: module))
    }
    func uri(of article:Article.Index, in pinned:Package.Pinned) -> URI
    {
        .init(root: self.root.article, path: pinned.path(to: article))
    }
    func uri(of composite:Symbol.Composite, in pinned:Package.Pinned) -> URI
    {
        .init(root: self.root.master, 
            path: pinned.path(to: composite, ecosystem: self), 
            query: pinned.query(to: composite, ecosystem: self), 
            orientation: self[composite.base].orientation)
    }
    func uri(of choices:[Symbol.Composite], pins:[Package.Index: Version]) -> URI
    {
        // `first` should always exist, if not, something has gone seriously 
        // wrong in swift-biome...
        guard let exemplar:Symbol.Composite = choices.first 
        else 
        {
            fatalError("empty disambiguation group")
        }
        let pinned:Package.Pinned = self[exemplar.culture.package].pinned(pins)
        return .init(root: self.root.master, 
            path: pinned.path(to: exemplar, ecosystem: self), 
            orientation: self[exemplar.base].orientation)
    }
    func uriOfSearchIndex(for package:Package.Index) -> URI 
    {
        .init(root: self.root.searchIndex, path: [self[package].name, "types"])
    }
    func uriOfSiteMap(for package:Package.Index) -> URI 
    {
        .init(root: self.root.sitemap, path: ["\(self[package].name).txt"])
    }
    
    func expand(_ link:Link) -> Link.Expansion
    {
        switch link.target 
        {
        case .package(let package): 
            return .package(package)
        case .module(let module): 
            return .module(module)
        case .article(let article): 
            return .article(article)
        case .composite(let composite):
            var trace:[Symbol.Composite] = []
                trace.reserveCapacity(link.visible)
                trace.append(composite)
            var next:Symbol.Index? = composite.host ?? self[composite.base].shape?.index
            while trace.count < link.visible
            {
                guard let current:Symbol.Index = next 
                else 
                {
                    let namespace:Module.Index = self[composite.diacritic.host].namespace
                    return .module(namespace, trace.reversed())
                }
                
                trace.append(.init(natural: current))
                next = self[current].shape?.index 
            }
            return .composite(trace.reversed())
        }
    }

    /// returns the index of the entry for the given package, creating it if it 
    /// does not already exist.
    mutating 
    func updatePackageRegistration(for package:Package.ID)
        throws -> Package.Index
    {
        if let package:Package.Index = self.indices[package]
        {
            return package 
        }
        else 
        {
            let index:Package.Index = .init(offset: self.packages.endIndex)
            self.packages.append(.init(id: package, index: index))
            self.indices[package] = index
            return index
        }
    }
    
    mutating 
    func updateModuleRegistrations(in culture:Package.Index,
        graphs:[Module.Graph], 
        version:PreciseVersion,
        era:[Package.ID: MaskedVersion])
        throws -> (pins:Package.Pins<Version>, scopes:[Symbol.Scope])
    {
        // create modules, if they do not exist already.
        // note: module indices are *not* necessarily contiguous, 
        // or even monotonically increasing
        let cultures:[Module.Index] = self[culture].addModules(graphs)
        
        let dependencies:[Set<Module.Index>] = 
            try self.computeDependencies(of: cultures, graphs: graphs)
        
        var packages:Set<Package.Index> = []
        for target:Module.Index in dependencies.joined()
        {
            packages.insert(target.package)
        }
        packages.remove(culture)
        // only include pins for actual package dependencies, this prevents 
        // extraneous pins in a Package.resolved from disrupting the version cache.
        let upstream:[Package.Index: Version] = 
            .init(uniqueKeysWithValues: packages.map
        {
            ($0, self[$0].versions.snap(era[self[$0].id]))
        })
        // must call this *before* `updateDependencies`
        let pins:Package.Pins<Version> = 
            self[culture].updateVersion(version, upstream: upstream)
        self[culture].updateDependencies(of: cultures, with: dependencies)
        
        return (pins, self.scopes(of: cultures, dependencies: dependencies))
    }
}
extension Ecosystem 
{
    private 
    func scopes(of cultures:[Module.Index], dependencies:[Set<Module.Index>])
        -> [Symbol.Scope]
    {
        zip(cultures, dependencies).map 
        {
            self.scope(of: $0.0, dependencies: $0.1)
        }
    }
    private 
    func scope(of culture:Module.Index, dependencies:Set<Module.Index>) 
        -> Symbol.Scope
    {
        var scope:Module.Scope = .init(culture: culture, id: self[culture].id)
        for namespace:Module.Index in dependencies 
        {
            scope.insert(namespace: namespace, id: self[namespace].id)
        }
        return .init(namespaces: scope, lenses: scope.upstream().map 
        {
            self[$0].symbols.indices
        })
    }
}
