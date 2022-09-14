import PackageResolution
import SymbolGraphs
import Versions

extension Package.Index 
{
    static 
    let swift:Self = .init(offset: 0)
    static 
    let core:Self = .init(offset: 1)
}
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
        precondition(core == .swift) 
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

    @available(*, deprecated, renamed: "subscript(global:)")
    subscript(module:Module.Index) -> Module
    {
        _read 
        {
            yield self.packages[       module.package.offset][local: module]
        }
    } 
    @available(*, deprecated, renamed: "subscript(global:)")
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
            yield self[module.package].tree[local: module]
        }
    } 
    subscript(global symbol:Tree.Position<Symbol>) -> Symbol
    {
        _read 
        {
            yield self[symbol.package].tree[local: symbol]
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
    func _add(package id:Package.ID, 
        resolved:__owned PackageResolution, 
        branch:String, 
        graphs:__owned [SymbolGraph], 
        stems:inout Route.Stems) 
        throws -> Package.Index
    {
        guard let pin:PackageResolution.Pin = resolved.pins[id]
        else 
        {
            fatalError("unimplemented")
        }
        
        let linkable:[Package.Index: _Dependency] = self.find(pins: resolved.pins.values)
        let package:Package.Index = self.add(package: id)
        let branch:_Version.Branch = self[package].tree.branch(from: nil, 
            name: branch)
        // we are going to mutate `self[package].tree[branch]`, so we must not 
        // capture that buffer or any slice of it!
        let fasces:Fasces = self[package].tree.fasces(upTo: branch)

        var surface:SurfaceBuilder = .init(previous: .init())

        var interfaces:[ModuleInterface] = []
            interfaces.reserveCapacity(graphs.count)
        for graph:SymbolGraph in graphs 
        {
            let module:Tree.Position<Module> = self[package].tree[branch].add(module: graph.id, 
                culture: package, 
                fasces: fasces)

            // use this instead of `graph.id` to prevent string duplication
            var namespaces:Namespaces = .init(id: self[global: module].id, 
                position: module)
            let upstream:[Package.Index: Package._Pinned] = try namespaces.link(
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

            surface.update(with: graph.edges, interface: interface, 
                context: .init(upstream: upstream, local: self[package]))
            
            interfaces.append(interface)
        }

        // successfully registered symbolgraph contents 
        let version:_Version = self.commit(pin.revision, to: branch, of: package, 
            pins: interfaces.reduce(into: [:]) 
            { 
                $0.merge($1.pins) { $1 }
            })

        self[package].tree[branch].routes.stack(routes: surface.routes.natural, 
            revision: version.revision)
        self[package].tree[branch].routes.stack(routes: surface.routes.synthetic.joined(), 
            revision: version.revision)

        surface.inferScopes(for: &self[package].tree[branch], 
            fasces: fasces, 
            stems: stems)

        self[package].updateMetadata(to: version, 
            interfaces: interfaces, 
            builder: surface,
            fasces: fasces)

        _ = _move surface

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
        to branch:_Version.Branch, 
        of index:Package.Index, 
        pins:[Package.Index: _Version])
        -> _Version
    {
        let version:_Version = self[index].tree[branch].commit(revision, pins: pins)
        for (package, pin):(Package.Index, _Version) in pins
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
            if  let version:_Version = package.tree.find(tag),
                    package.tree[version].hash == pin.revision
            {
                linkable[package.index] = .available(version)
            }
            else 
            {
                linkable[package.index] = .unavailable(tag, pin.revision)
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
