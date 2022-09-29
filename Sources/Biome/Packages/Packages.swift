import PackageResolution
import SymbolGraphs
import Versions

public 
struct Packages
{
    private 
    var packages:[Package]
    private(set)
    var index:[PackageIdentifier: Index]
    
    init()
    {
        self.packages = []
        self.index = [:]

        // swift-standard-library is always index = 0
        // swift-core-libraries is always index = 1
        let swift:Index = self.add(package: .swift)
        let core:Index = self.add(package: .core)

        precondition(swift == .swift) 
        precondition(core == .core) 
    }
}
extension Packages:RandomAccessCollection
{
    public 
    var startIndex:Index
    {
        .init(offset: .init(self.packages.startIndex))
    }
    public 
    var endIndex:Index
    {
        .init(offset: .init(self.packages.endIndex))
    }
    public 
    subscript(package:Index) -> Package
    {
        _read 
        {
            yield  self.packages[.init(package.offset)]
        }
        _modify 
        {
            yield &self.packages[.init(package.offset)]
        }
    } 
}
extension Packages 
{
    var swift:Package 
    {
        _read 
        {
            yield self[.swift]
        }
    }
    var core:Package 
    {
        _read 
        {
            yield self[.core]
        }
    }
    
    subscript(package:PackageIdentifier) -> Package?
    {
        self.index[package].map { self[$0] }
    }

    //@available(*, deprecated, renamed: "subscript(global:)")
    subscript(module:Module.Index) -> Module
    {
        _read 
        {
            yield self[module.nationality][local: module]
        }
    } 
    //@available(*, deprecated, renamed: "subscript(global:)")
    subscript(symbol:Symbol.Index) -> Symbol
    {
        _read 
        {
            yield self[symbol.nationality][local: symbol]
        }
    } 
    //@available(*, deprecated, renamed: "subscript(global:)")
    subscript(article:Article.Index) -> Article
    {
        _read 
        {
            yield self[article.nationality][local: article]
        }
    } 

    subscript(global module:Atom<Module>.Position) -> Module
    {
        _read 
        {
            yield self[module.nationality].tree[local: module]
        }
    } 
    subscript(global article:Atom<Article>.Position) -> Article
    {
        _read 
        {
            yield self[article.nationality].tree[local: article]
        }
    } 
    subscript(global symbol:Atom<Symbol>.Position) -> Symbol
    {
        _read 
        {
            yield self[symbol.nationality].tree[local: symbol]
        }
    } 

    mutating 
    func _add(package id:PackageIdentifier, 
        resolved:__owned PackageResolution, 
        branch:Tag, 
        fork:Version.Selector?,
        date:Date, 
        tag:Tag?, 
        graphs:__owned [SymbolGraph], 
        stems:inout Route.Stems) 
        throws -> Index
    {
        guard let pin:PackageResolution.Pin = resolved.pins[id]
        else 
        {
            fatalError("unimplemented")
        }

        let (package, fork):(Index, Version?) = self.add(package: id, fork: fork)
        let branch:Version.Branch = self[package].tree.branch(branch, from: fork)

        let linkable:[Index: _Dependency] = self.find(pins: resolved.pins.values)
        // we are going to mutate `self[package].tree[branch]`, so we must not 
        // capture that buffer or any slice of it!
        let fasces:Fasces = self[package].tree.fasces(upTo: branch)
        var api:SurfaceBuilder = .init(
            previous: self[package].tree[fork?.branch ?? branch]._surface)

        var interfaces:[ModuleInterface] = []
            interfaces.reserveCapacity(graphs.count)
        for graph:SymbolGraph in graphs 
        {
            let module:Atom<Module>.Position = self[package].tree[branch].add(module: graph.id,
                culture: package, 
                fasces: fasces)

            // use this instead of `graph.id` to prevent string duplication
            var namespaces:Namespaces = .init(id: self[global: module].id, 
                position: module)
            let upstream:[Index: Package.Pinned] = try namespaces.link(
                dependencies: graph.dependencies, 
                linkable: linkable, 
                branch: branch,
                fasces: fasces,
                context: self)

            // all of the fasces in `fasces` are from different branches, 
            // so this will not cause copy-on-write.
            let interface:ModuleInterface = self[package].tree[branch].add(graph: graph, 
                namespaces: _move namespaces, 
                upstream: upstream,
                fasces: fasces,
                stems: &stems)

            api.update(with: graph.edges, interface: interface, 
                context: .init(upstream: upstream, local: self[package]))
            
            interfaces.append(interface)
        }

        // successfully registered symbolgraph contents 
        let version:Version = self.commit(pin.revision, to: branch, of: package, 
            interfaces: interfaces, 
            date: date, 
            tag: tag)
        self[package].tree[branch]._surface = api.surface()
        
        self[package].tree[branch].routes.stack(routes: api.routes.atomic, 
            revision: version.revision)
        self[package].tree[branch].routes.stack(routes: api.routes.compound.joined(), 
            revision: version.revision)

        api.inferScopes(for: &self[package].tree[branch], 
            fasces: fasces, 
            stems: stems)

        self[package].updateMetadata(to: version, 
            interfaces: interfaces, 
            builder: api,
            fasces: fasces)

        _ = _move api

        for (graph, interface):(SymbolGraph, ModuleInterface) in zip(graphs, interfaces)
        {
            self[package].updateData(to: version, graph: graph, 
                interface: interface, 
                fasces: fasces) 
        }

        let literature:Literature = .init(compiling: _move graphs, 
            interfaces: _move interfaces, 
            package: package, 
            version: version,
            context: self, 
            stems: stems)

        self[package].updateDocumentation(to: version, 
            literature: _move literature, 
            fasces: fasces)
        
        return package
    }
    
    /// Returns the index of the package referenced by the given identifier, and 
    /// the fork location within it, if a fork selector is provided.
    /// 
    /// This method will only create package descriptors if `fork` is [`nil`]().
    private mutating 
    func add(package id:PackageIdentifier, fork:Version.Selector?) -> (Index, Version?)
    {
        if  let fork:Version.Selector 
        {
            guard   let package:Index = self.index[id], 
                    let fork:Version = self[package].tree.find(fork)
            else 
            {
                fatalError("couldn’t find tag to fork from")
            }
            guard case fork.revision? = self[package].tree[fork.branch].head 
            else 
            {
                // we can relax this restriction once we have a way of persisting 
                // API surfaces for revisions besides the branch head 
                fatalError("can only fork from branch head (for now)")
            }
            return (package, fork)
        }
        else 
        {
            return (self.add(package: id), nil)
        }
    }
    /// Creates a package entry for the given package graph, if it does not already exist.
    /// 
    /// -   Returns: The index of the package, identified by its ``PackageIdentifier``.
    private mutating 
    func add(package:PackageIdentifier) -> Index
    {
        if let index:Index = self.index[package]
        {
            return index 
        }
        else 
        {
            let index:Index = self.endIndex
            self.packages.append(.init(id: package, index: index))
            self.index[package] = index
            return index
        }
    }

    private mutating
    func commit(_ revision:String, 
        to branch:Version.Branch, 
        of nationality:Index, 
        interfaces:[ModuleInterface], 
        date:Date, 
        tag:Tag?) -> Version
    {
        var pins:[Index: (version:Version, consumers:Set<Atom<Module>>)] = [:]
        for interface:ModuleInterface in interfaces 
        {
            for (package, pin):(Index, Version) in interface.pins 
            {
                pins[package, default: (pin, [])].consumers.insert(interface.culture)
            }
        }
        let version:Version = self[nationality].tree.commit(branch: branch, hash: revision, 
            pins: pins.mapValues(\.version), 
            date: date, 
            tag: tag)
        for (package, (pin, consumers)):(Index, (Version, Set<Atom<Module>>)) in pins
        {
            assert(package != nationality)
            self[package].tree[pin].consumers[nationality, default: [:]][version] = consumers
        }
        return version
    }
}
extension Packages 
{
    private 
    func find(pins:some Sequence<PackageResolution.Pin>) -> [Index: _Dependency]
    {
        var linkable:[Index: _Dependency] = [:]
        for pin:PackageResolution.Pin in pins 
        {
            guard   let package:Package = self[pin.id],
                    let tag:Tag = .init(pin.requirement)
            else 
            {
                continue 
            }
            if  let version:Version = package.tree.find(tag),
                    package.tree[version].hash == pin.revision
            {
                linkable[package.nationality] = .available(version)
            }
            else 
            {
                linkable[package.nationality] = .unavailable(tag, pin.revision)
            }
        }
        return linkable
    }
}
extension Packages 
{
    // mutating 
    // func spread(from index:Packages.Index, beliefs:Beliefs)
    // {
    //     let current:Version = self[index].versions.latest
    //     for diacritic:Symbol.Diacritic in beliefs.opinions.keys 
    //     {
    //         self[diacritic.host.module.package].pollinate(local: diacritic.host, 
    //             from: .init(culture: diacritic.culture, version: current))
    //     }
    // }
}
