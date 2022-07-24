import SymbolGraphs
import Versions

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
    func updatePackageRegistration(for graph:PackageGraph) -> Package.Index
    {
        let index:Package.Index
        if  let package:Package.Index = self.indices[graph.id]
        {
            index = package 
        }
        else 
        {
            index = .init(offset: self.packages.endIndex)
            self.packages.append(.init(id: graph.id, index: index))
            self.indices[graph.id] = index
        }
        if let brand:String = graph.brand 
        {
            self[index].brand = brand
        }
        return index
    }
    mutating 
    func updatePackageVersion(for package:Package.Index, 
        version:PreciseVersion, 
        scopes:[Module.Scope], 
        era:[Package.ID: MaskedVersion])
        -> Package.Pins
    {
        self[index].updateVersion(version, 
            upstream: self.computeUpstreamPins(scopes, era: era))
    }
}
extension Packages 
{
    func computeScopes(of cultures:[Module.Index], graphs:[SymbolGraph]) 
        throws -> [Module.Scope]
    {
        var scopes:[Module.Scope] = []
            scopes.reserveCapacity(graphs.count)
        for (graph, culture):(SymbolGraph, Module.Index) in zip(graphs, cultures)
        {
            var scope:Module.Scope = .init(culture: culture, id: self[culture].id)
            for dependency:Module.Index in try self.identify(graph.dependencies)
            {
                scope.insert(dependency, id: self[dependency].id)
            }
            scopes.append(scope)
        }
        return scopes
    }

    private 
    func computeUpstreamPins(_ scopes:[Module.Scope], era:[Package.ID: MaskedVersion])
        -> [Package.Index: Version]
    {
        var packages:Set<Package.Index> = []
        for scope:Module.Scope in scopes 
        {
            for namespace:Module.Index in scope.filter 
                where namespace.package != scope.culture.package
            {
                packages.insert(namespace.package)
            }
        }
        // only include pins for actual package dependencies, this prevents 
        // extraneous pins in a Package.resolved from disrupting the version cache.
        return .init(uniqueKeysWithValues: packages.map
        {
            ($0, self[$0].versions.snap(era[self[$0].id]))
        })
    }
    private 
    func identify(_ dependencies:[SymbolGraph.Dependency]) throws -> Set<Module.Index>
    {
        let packages:[Package.ID: [Module.ID]] = [Package.ID: [SymbolGraph.Dependency]]
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
    func translate(_ identifiers:[Symbol.ID], scope:Module.Scope) -> [Symbol.Index?]
    {
        // includes the current package 
        let packages:Set<Package.Index> = .init(scope.filter.lazy.map(\.package))
        let lenses:[[Symbol.ID: Symbol.Index]] = packages.map 
        { 
            self[$0].symbols.indices 
        }
        return identifiers.map 
        {
            var match:Symbol.Index? = nil
            for lens:[Symbol.ID: Symbol.Index] in lenses
            {
                guard let index:Symbol.Index = lens[id], scope.contains(index.module)
                else 
                {
                    continue 
                }
                if case nil = match 
                {
                    match = index
                }
                else 
                {
                    // sanity check: ensure none of the remaining lenses contains 
                    // a colliding key 
                    fatalError("colliding symbol identifiers in search space")
                }
            }
            return match
        }
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
