import PackageResolution
import SymbolGraphs
import Versions

extension Package.Index 
{
    static 
    let swift:Self = .init(offset: 0)
    static 
    let core:Self = .init(offset: 1) 

    var isCommunityPackage:Bool
    {
        self.offset > 1
    }
}
public 
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

        // swift-standard-library is always index = 0
        // swift-core-libraries is always index = 1
        let swift:Package.Index = self.add(package: .swift)
        let core:Package.Index = self.add(package: .core)

        precondition(swift == .swift) 
        precondition(core == .core) 
    }

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

    //@available(*, deprecated, renamed: "subscript(global:)")
    subscript(module:Module.Index) -> Module
    {
        _read 
        {
            yield self.packages[module.nationality.offset][local: module]
        }
    } 
    //@available(*, deprecated, renamed: "subscript(global:)")
    subscript(symbol:Symbol.Index) -> Symbol
    {
        _read 
        {
            yield self.packages[symbol.nationality.offset][local: symbol]
        }
    } 
    subscript(article:Article.Index) -> Article
    {
        _read 
        {
            yield self.packages[article.nationality.offset][local: article]
        }
    } 

    subscript(global module:PluralPosition<Module>) -> Module
    {
        _read 
        {
            yield self[module.nationality].tree[local: module]
        }
    } 
    subscript(global symbol:PluralPosition<Symbol>) -> Symbol
    {
        _read 
        {
            yield self[symbol.nationality].tree[local: symbol]
        }
    } 

    mutating 
    func _add(package id:Package.ID, 
        resolved:__owned PackageResolution, 
        branch:Tag, 
        fork:Version.Selector?,
        date:Date, 
        tag:Tag?, 
        graphs:__owned [SymbolGraph], 
        stems:inout Route.Stems) 
        throws -> Package.Index
    {
        guard let pin:PackageResolution.Pin = resolved.pins[id]
        else 
        {
            fatalError("unimplemented")
        }

        let (package, fork):(Package.Index, Version?) = self.add(package: id, fork: fork)
        let branch:Version.Branch = self[package].tree.branch(branch, from: fork)

        let linkable:[Package.Index: _Dependency] = self.find(pins: resolved.pins.values)
        // we are going to mutate `self[package].tree[branch]`, so we must not 
        // capture that buffer or any slice of it!
        let fasces:Fasces = self[package].tree.fasces(upTo: branch)
        var api:SurfaceBuilder = .init(
            previous: self[package].tree[fork?.branch ?? branch]._surface)

        var interfaces:[ModuleInterface] = []
            interfaces.reserveCapacity(graphs.count)
        for graph:SymbolGraph in graphs 
        {
            let module:PluralPosition<Module> = self[package].tree[branch].add(module: graph.id, 
                culture: package, 
                fasces: fasces)

            // use this instead of `graph.id` to prevent string duplication
            var namespaces:Namespaces = .init(id: self[global: module].id, 
                position: module)
            let upstream:[Package.Index: Package.Pinned] = try namespaces.link(
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
            pins: interfaces.reduce(into: [:]) 
            { 
                $0.merge($1.pins) { $1 }
            }, 
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
    func add(package id:Package.ID, fork:Version.Selector?) -> (Package.Index, Version?)
    {
        if  let fork:Version.Selector 
        {
            guard   let package:Package.Index = self.indices[id], 
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
    /// -   Returns: The index of the package, identified by its ``Package.ID``.
    private mutating 
    func add(package:Package.ID) -> Package.Index
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

    private mutating
    func commit(_ revision:String, 
        to branch:Version.Branch, 
        of index:Package.Index, 
        pins:[Package.Index: Version], 
        date:Date, 
        tag:Tag?) -> Version
    {
        let version:Version = self[index].tree[branch].commit(hash: revision, pins: pins, 
            date: date, 
            tag: tag)
        for (package, pin):(Package.Index, Version) in pins
        {
            assert(package != index)
            self[package].tree[pin].consumers[index, default: []].insert(version)
        }
        return version
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
    // func spread(from index:Package.Index, beliefs:Beliefs)
    // {
    //     let current:Version = self[index].versions.latest
    //     for diacritic:Symbol.Diacritic in beliefs.opinions.keys 
    //     {
    //         self[diacritic.host.module.package].pollinate(local: diacritic.host, 
    //             from: .init(culture: diacritic.culture, version: current))
    //     }
    // }
}
