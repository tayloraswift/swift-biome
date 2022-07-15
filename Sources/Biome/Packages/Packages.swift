struct Packages 
{
    private 
    var packages:[Package]
    private(set)
    var indices:[Package.ID: Package.Index]
    
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
        throws -> (pins:Package.Pins, scopes:[Symbol.Scope])
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
        let pins:Package.Pins = self[culture].updateVersion(version, 
            upstream: upstream)
        self[culture].updateDependencies(of: cultures, with: dependencies)
        
        return (pins, self.scopes(of: cultures, dependencies: dependencies))
    }
    
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
extension Packages 
{
    func computeDependencies(of cultures:[Module.Index], graphs:[Module.Graph]) 
        throws -> [Set<Module.Index>]
    {
        var dependencies:[Set<Module.Index>] = []
            dependencies.reserveCapacity(cultures.count)
        for (graph, culture):(Module.Graph, Module.Index) in zip(graphs, cultures)
        {
            // remove self-dependencies 
            var set:Set<Module.Index> = try self.identify(graph.dependencies)
                set.remove(culture)
            dependencies.append(set)
        }
        return dependencies
    }
    
    private 
    func identify(_ dependencies:[Module.Graph.Dependency]) throws -> Set<Module.Index>
    {
        let packages:[Package.ID: [Module.ID]] = [Package.ID: [Module.Graph.Dependency]]
            .init(grouping: dependencies, by: \.package)
            .mapValues 
        {
            $0.flatMap(\.modules)
        }
        // add implicit dependencies 
        var namespaces:Set<Module.Index> = self.standardLibrary
        if let core:Package = self[.core]
        {
            namespaces.formUnion(core.modules.indices.values)
        }
        for (dependency, targets):(Package.ID, [Module.ID]) in packages
        {
            guard let package:Package = self[dependency]
            else 
            {
                throw DependencyError.packageNotFound(dependency)
            }
            for target:Module.ID in targets
            {
                guard let index:Module.Index = package.modules.indices[target]
                else 
                {
                    throw DependencyError.targetNotFound(target, in: dependency)
                }
                namespaces.insert(index)
            }
        }
        return namespaces
    }
}
extension Packages 
{
    mutating 
    func updateDocumentation(_ compiled:Ecosystem.Documentation,
        hints:[Symbol.Index: Symbol.Index], 
        pins:Package.Pins)
    {
        self[pins.local.package].updateDocumentation(compiled)
        self[pins.local.package].spreadDocumentation(
            self.recruitMigrants(sponsors: compiled, hints: hints, pins: pins))
    }
    // `culture` parameter not strictly needed, but we use it to make sure 
    // that ``generateRhetoric(graphs:scopes:)`` did not return ``hints``
    // about other packages
    private 
    func recruitMigrants(
        sponsors:[Ecosystem.Index: Article.Template<Ecosystem.Link>],
        hints:[Symbol.Index: Symbol.Index], 
        pins:Package.Pins) 
        -> [Symbol.Index: Article.Template<Ecosystem.Link>]
    {
        var migrants:[Symbol.Index: Article.Template<Ecosystem.Link>] = [:]
        for (member, sponsor):(Symbol.Index, Symbol.Index) in hints
            where !sponsors.keys.contains(.symbol(member))
        {
            assert(member.module.package == pins.local.package)
            // if a symbol did not have documentation of its own, 
            // check if it has a sponsor. article templates are copy-on-write 
            // types, so this will not (eagarly) copy storage
            if  let template:Article.Template<Ecosystem.Link> = sponsors[.symbol(sponsor)] 
            {
                migrants[member] = template
            }
            // note: empty doccomments are omitted from the template buffer
            else if pins.local.package != sponsor.module.package
            {
                let template:Article.Template<Ecosystem.Link> = 
                    self[sponsor.module.package].pinned(pins).template(sponsor)
                if !template.isEmpty
                {
                    migrants[member] = template
                }
            }
        }
        return migrants
    }
}
