/// an ecosystem is a subset of a biome containing packages that are relevant 
/// (in some user-defined way) to some task. 
/// 
/// ecosystem views are mainly useful for providing an immutable context for 
/// accessing foreign packages.
struct Ecosystem 
{
    enum DependencyError:Error 
    {
        case packageNotFound(Package.ID)
        case targetNotFound(Module.ID, in:Package.ID)
    }
    enum AuthorityError:Error
    {
        case externalSymbol(Symbol.Index, is:Symbol.Role, accordingTo:Module.Index)
    }
    enum LinkResolutionError:Error 
    {
        case none(String)
        case many(String, [Symbol.Composite])
    }
    
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
    
    func describe(_ error:LinkResolutionError) -> String 
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
    }
    
    let prefix:
    (    
        master:String,
        doc:String,
        lunr:String
    )
    private(set)
    var packages:[Package], 
        indices:[Package.ID: Package.Index]
        
    func pinned(_ pins:[Package.Index: Version]) -> Pinned 
    {
        .init(self, pins: pins)
    }

    init(prefixes:[URI.Prefix: String])
    {
        self.prefix = 
        (
            master: prefixes[.master,   default: "reference"],
            doc:    prefixes[.doc,      default: "learn"],
            lunr:   prefixes[.lunr,     default: "lunr"]
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
    
    func uri(of resolution:Resolution) -> URI 
    {
        switch resolution 
        {        
        case .selection(let selection, let pins):
            return self.pinned(pins).uri(of: selection)
        case .searchIndex(let package): 
            return .init(prefix: self.prefix.lunr, 
                path: [self[package].name, "types"])
        }
    }
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
        .init(prefix: self.prefix.master, path: pinned.path())
    }
    func uri(of module:Module.Index, in pinned:Package.Pinned) -> URI
    {
        .init(prefix: self.prefix.master, path: pinned.path(to: module))
    }
    func uri(of article:Article.Index, in pinned:Package.Pinned) -> URI
    {
        .init(prefix: self.prefix.doc, path: pinned.path(to: article))
    }
    func uri(of composite:Symbol.Composite, in pinned:Package.Pinned) -> URI
    {
        .init(prefix: self.prefix.master, 
            path: pinned.path(to: composite, ecosystem: self), 
            query: pinned.query(to: composite, ecosystem: self), 
            orientation: self[composite.base].orientation)
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
