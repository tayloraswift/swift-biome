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
        
        var culture:Package.Index 
        {
            switch self 
            {
            case .package(let package):     return package 
            case .module(let module):       return module.package 
            case .article(let article):     return article.module.package 
            case .composite(let composite): return composite.culture.package 
            }
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
    
    var packages:[Package], 
        indices:[Package.ID: Package.Index]
    
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
    
    init()
    {
        self.packages = []
        self.indices = [:]
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
    
    // returns the components in reversed order
    func expand(link:Link) -> [Index]
    {
        var trace:[Index] = [link.target]
        guard case .composite(let composite) = link.target
        else 
        {
            return trace
        }
        
        trace.reserveCapacity(link.visible)
        var next:Symbol.Index? = composite.host ?? self[composite.base].shape?.index
        while trace.count < link.visible, let current:Symbol.Index = next 
        {
            trace.append(.symbol(current))
            next = self[current].shape?.index 
        }
        return trace
    }

    /// returns the index of the entry for the given package, creating it if it 
    /// does not already exist.
    mutating 
    func updatePackageRegistration(for package:Package.ID, to version:Version)
        throws -> Package.Index
    {
        if  let package:Package.Index = self.indices[package]
        {
            let previous:Version = self[package].latest
            guard previous < version
            else 
            {
                throw Package.UpdateError.versionNotIncremented(version, from: previous)
            }
            self[package].latest = version
            return package 
        }
        else 
        {
            let index:Package.Index = .init(offset: self.packages.endIndex)
            self.packages.append(.init(id: package, index: index, version: version))
            self.indices[package] = index
            return index
        }
    }
    
    mutating 
    func updateModuleRegistrations(in culture:Package.Index,
        graphs:[Module.Graph], 
        era:[Package.ID: Version])
        throws -> (pins:Package.Pins, scopes:[Symbol.Scope])
    {
        // create modules, if they do not exist already.
        // note: module indices are *not* necessarily contiguous, 
        // or even monotonically increasing
        let cultures:[Module.Index] = self[culture].addModules(graphs)
        
        let dependencies:[Set<Module.Index>] = 
            try self.computeDependencies(of: cultures, graphs: graphs)
        
        var upstream:Set<Package.Index> = []
        for target:Module.Index in dependencies.joined()
        {
            upstream.insert(target.package)
        }
        upstream.remove(culture)
        // only include pins for actual package dependencies, this prevents 
        // extraneous pins in a Package.resolved from disrupting the version cache.
        let pins:Package.Pins = .init(version: self[culture].latest,
            upstream: .init(uniqueKeysWithValues: upstream.map
        {
            let package:Package = self[$0]
            return ($0, era[package.id] ?? package.latest)
        }))
        
        self[culture].updatePins(pins)
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
extension Ecosystem 
{
    func declaration(_ symbol:Symbol.Index, at version:Version)
        -> Symbol.Declaration
    {
        // `nil` case should be unreachable in practice
        self[symbol.module.package].declarations
            .at(version, head: self[symbol].heads.declaration) ?? 
            .init(fallback: "<unavailable>")
    }
    func template(_ symbol:Symbol.Index, at version:Version)
        -> Article.Template<Link>
    {
        self[symbol.module.package].templates
            .at(version, head: self[symbol].heads.template) ?? 
            .init()
    }
    func facts(_ symbol:Symbol.Index, at version:Version)
        -> Symbol.Predicates
    {
        // `nil` case should be unreachable in practice
        self[symbol.module.package].facts
            .at(version, head: self[symbol].heads.facts) ?? 
            .init(roles: nil)
    }
    /* func opinions(of symbol:Symbol.Index, from pin:Module.Pin)
        -> Symbol.Traits?
    {
        let diacritic:Symbol.Diacritic = .init(host: symbol, culture: pin.culture)
        return self[pin.culture.package].opinions
            .at(pin.version, head: self[pin.culture.package].external[diacritic])
    } */
    func currentOpinions(of symbol:Symbol.Index, from culture:Module.Index)
        -> Symbol.Traits?
    {
        self[culture.package].external[.init(host: symbol, culture: culture)].map 
        {
            self[culture.package].opinions[$0].value
        }
    }
    
    func baseDeclaration(_ composite:Symbol.Composite, pins:[Package.Index: Version])
        -> Symbol.Declaration
    {
        self.declaration(composite.base, at: self.baseVersion(composite, pins: pins))
    }
    func baseTemplate(_ composite:Symbol.Composite, pins:[Package.Index: Version])
        -> Article.Template<Link>
    {
        self.template(composite.base, at: self.baseVersion(composite, pins: pins)) 
    }
    
    private 
    func baseVersion(_ composite:Symbol.Composite, pins:[Package.Index: Version]) 
        -> Version
    {
        pins[composite.base.module.package] ?? self[composite.base.module.package].latest
    }
}
