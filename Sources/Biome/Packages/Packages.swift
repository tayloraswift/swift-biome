import PackageResolution
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

    subscript(global module:Tree.Position<Module>) -> Module
    {
        _read 
        {
            yield self[module.index.package].tree[local: module]
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

    mutating 
    func _add(_ id:Package.ID, resolved:PackageResolution, graphs:[SymbolGraph], 
        stems:inout Route.Stems) 
        throws
    {
        let graphs:[SymbolGraph] = try Self.sort(id, graphs: graphs)
        let index:Package.Index = self.addPackage(id)

        // we are going to mutate `self[index].tree[branch]`, so we must not 
        // capture that buffer or any slice of it!
        let branch:_Version.Branch = self[index].tree.branch(resolved.pins[id])
        let trunks:[Trunk] = self[index].tree.trunks(of: branch)

        let linkable:[Package.Index: _Dependency] = self.find(pins: resolved.pins.values)

        for graph:SymbolGraph in graphs 
        {
            let module:Tree.Position<Module> = self[index].tree[branch].add(module: graph.id, 
                culture: index, 
                trunks: trunks) 
            // use this instead of `graph.id` to prevent string duplication
            var namespaces:Namespaces = .init(id: self[global: module].id, position: module) 
            var lenses:[Trunk] = trunks 
            // add explicit dependencies 
            for dependency:SymbolGraph.Dependency in graph.dependencies
            {
                let trunks:[Trunk] = try namespaces.link(package: dependency.package, 
                    dependencies: dependency.modules, 
                    linkable: linkable, 
                    context: self)
                //  don’t accidentally capture the buffer we are trying to modify!
                if  dependency.package != id 
                {
                    lenses.append(contentsOf: trunks)
                }
            }
            // add implicit dependencies
            switch self[module.index.package].kind
            {
            case .community(_): 
                lenses.append(contentsOf: try namespaces.link(package: .core, 
                    linkable: linkable, 
                    context: self))
                fallthrough 
            case .core: 
                lenses.append(contentsOf: try namespaces.link(package: .swift, 
                    linkable: linkable, 
                    context: self))
            case .swift: 
                break 
            }
            // all of the trunks in `lenses` are from different branches, 
            // so this will not cause copy-on-write.
            let (abstractor, _rendered):(_Abstractor, [Extension]) = self[index].tree[branch].add(graph: graph, 
                namespaces: namespaces, 
                trunks: lenses, 
                stems: &stems) 
        }
    }
    
    /// Creates a package entry for the given package graph, if it does not already exist.
    /// 
    /// -   Returns: The index of the package, identified by its ``Package.ID``.
    private mutating 
    func addPackage(_ package:Package.ID) -> Package.Index
    {
        if let index:Package.Index = self.indices[package]
        {
            return index 
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
    func updatePackageVersion(for index:Package.Index, 
        version:PreciseVersion, 
        scopes:[Module.Scope], 
        era:[Package.ID: MaskedVersion])
        -> Package.Pins
    {
        let pins:Package.Pins = self[index].updateVersion(version, 
            dependencies: self.computeUpstreamPins(scopes, era: era))
        for (package, version):(Package.Index, Version) in pins.dependencies 
        {
            self[package].versions[version].consumers[index, default: []].insert(pins.local.version)
        }
        return pins
    }
}
extension Packages 
{
    private 
    func find(pins:some Sequence<PackageResolution.Pin>) -> [Package.Index: _Dependency]
    {
        var linkable:[Package.Index: _Dependency] = [:]
        for pin:PackageResolution.Pin in pins 
        {
            if let package:Package = self[pin.id]
            {
                linkable[package.index] = package.tree.find(pin)
            }
        }
        return linkable
    }
    @available(*, deprecated)
    func resolveDependencies(graphs:[SymbolGraph], cultures:[Module.Index]) throws -> [Module.Scope]
    {
        var scopes:[Module.Scope] = []
            scopes.reserveCapacity(graphs.count)
        for (graph, culture):(SymbolGraph, Module.Index) in zip(graphs, cultures)
        {
            var scope:Module.Scope = .init(culture: culture, id: self[culture].id)
            // add explicit dependencies 
            for dependency:SymbolGraph.Dependency in graph.dependencies
            {
                guard let package:Package = self[dependency.package]
                else 
                {
                    throw DependencyError.packageNotFound(dependency.package)
                }
                for target:Module.ID in dependency.modules
                {
                    guard let index:Module.Index = package.modules.indices[target]
                    else 
                    {
                        throw DependencyError.moduleNotFound(target, in: dependency.package)
                    }
                    // use the stored id, not `target`
                    scope.insert(index, id: package[local: index].id)
                }
            }
            // add implicit dependencies
            switch self[culture.package].kind
            {
            case .community(_): 
                for module:Module in self[.core]?.modules.all ?? []
                {
                    scope.insert(module.index, id: module.id)
                } 
                fallthrough 
            case .core: 
                for module:Module in self[.swift]?.modules.all ?? []
                {
                    scope.insert(module.index, id: module.id)
                } 
            case .swift: 
                break 
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
}
extension Packages 
{
    mutating 
    func spread(from index:Package.Index, beliefs:Beliefs)
    {
        let current:Version = self[index].versions.latest
        for diacritic:Symbol.Diacritic in beliefs.opinions.keys 
        {
            self[diacritic.host.module.package].pollinate(local: diacritic.host, 
                from: .init(culture: diacritic.culture, version: current))
        }
    }
}
