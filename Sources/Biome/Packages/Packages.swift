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
    func _add(_ id:Package.ID, resolved:PackageResolution, graphs:[SymbolGraph]) 
        throws
    {
        let graphs:[SymbolGraph] = try Self.sort(id, graphs: graphs)
        let index:Package.Index = self.addPackage(id)

        let branch:_Version.Branch = self[index].tree.branch(resolved.pins[id])
        let trunks:[Trunk] = self[index].tree.trunks(of: branch)

        let linkable:[Package.Index: _Dependency] = self.find(pins: resolved.pins.values)

        for graph:SymbolGraph in graphs 
        {
            let position:Tree.Position<Module> = self[index].tree[branch].addModule(graph.id, 
                culture: index, 
                trunks: trunks)
            let namespaces:Namespaces = try self.computeDependencies(graph.dependencies, 
                linkable: linkable,
                position: position,
                trunks: trunks) 
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
    func computeDependencies(_ dependencies:[SymbolGraph.Dependency], 
        linkable:[Package.Index: _Dependency],
        position:Tree.Position<Module>, 
        trunks:[Trunk])
        throws -> Namespaces
    {
        var namespaces:Namespaces = .init(id: self[global: position].id, 
            position: position, 
            trunks: trunks)
        // add explicit dependencies 
        for dependency:SymbolGraph.Dependency in dependencies
        {
            guard let package:Package = self[dependency.package]
            else 
            {
                throw _DependencyError.package(unavailable: dependency.package)
            }
            switch linkable[package.index] 
            {
            case nil:
                throw _DependencyError.pin(unavailable: package.id)
            case .unavailable(let requirement, let revision):
                throw _DependencyError.version(unavailable: (requirement, revision), package.id)
            case .available(let version):
                let trunks:[Trunk] = package.tree.trunks(version)
                let modules:[(id:Module.ID, position:Tree.Position<Module>)] = 
                    try dependency.modules.map
                {
                    if let module:Tree.Position<Module> = trunks.find(module: $0)
                    {
                        // use the stored id, not the requested id
                        return (package.tree[local: module].id, module)
                    }
                    else 
                    {
                        let branch:Branch = package.tree[version.branch]
                        throw _DependencyError.module(unavailable: $0, 
                            (branch.id, branch[version.revision].hash), 
                            package.id)
                    }
                }

                namespaces.link(modules: modules, trunks: trunks)
            }
        }
        // add implicit dependencies
        switch self[position.index.package].kind
        {
        case .community(_): 
            if  let core:Package = self[.core], 
                case .available(let version)? = linkable[core.index] 
            {
                let trunks:[Trunk] = core.tree.trunks(version)
                let modules:[(id:Module.ID, position:Tree.Position<Module>)] = trunks.flatMap 
                {
                    (trunk:Trunk) in trunk.modules.map 
                    {
                        ($0.id, trunk.position($0.index))
                    }
                }

                namespaces.link(modules: modules, trunks: trunks)
            }
            fallthrough 
        case .core: 
            if  let swift:Package = self[.swift], 
                case .available(let version)? = linkable[swift.index] 
            {
                let trunks:[Trunk] = swift.tree.trunks(version)
                let modules:[(id:Module.ID, position:Tree.Position<Module>)] = trunks.flatMap 
                {
                    (trunk:Trunk) in trunk.modules.map 
                    {
                        ($0.id, trunk.position($0.index))
                    }
                }
                
                namespaces.link(modules: modules, trunks: trunks)
            }
        case .swift: 
            break 
        }
        return namespaces
    }
    
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
