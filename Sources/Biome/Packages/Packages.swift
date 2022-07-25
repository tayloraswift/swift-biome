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
    func updatePackageVersion(for index:Package.Index, 
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
    mutating 
    func spread(from index:Package.Index, beliefs:Beliefs)
    {
        self[index].reshape(beliefs.facts)

        let current:Version = self[index].versions.latest
        for diacritic:Symbol.Diacritic in beliefs.opinions.keys 
        {
            self[diacritic.host.module.package].pollinate(local: diacritic.host, 
                from: .init(culture: diacritic.culture, version: current))
        }
    }
}
