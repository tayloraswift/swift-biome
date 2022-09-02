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
            yield self[module.index.package].tree[local: module]
        }
    } 
    subscript(global symbol:Tree.Position<Symbol>) -> Symbol
    {
        _read 
        {
            yield self[symbol.index.module.package].tree[local: symbol]
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
    func _add(package id:Package.ID, resolved:PackageResolution, graphs:[SymbolGraph], 
        stems:inout Route.Stems) 
        throws -> Package.Index
    {
        guard let pin:PackageResolution.Pin = resolved.pins[id]
        else 
        {
            fatalError("unimplemented")
        }
        
        let index:Package.Index = self.add(package: id)
        let branch:_Version.Branch = self[index].tree.branch(from: nil, 
            name: .init(pin.requirement))
        // we are going to mutate `self[index].tree[branch]`, so we must not 
        // capture that buffer or any slice of it!
        let fasces:[Fascis] = self[index].tree.fasces(upTo: branch)

        // `pins` is a subset of `linkable`; it gets filled in gradually as we 
        // resolve dependencies. this allows us to discard unused dependencies 
        // from the `Package.resolved` file.
        let linkable:[Package.Index: _Dependency] = self.find(pins: resolved.pins.values)

        var targets:[Namespaces] = []
            targets.reserveCapacity(graphs.count)
        var abstractors:[_Abstractor] = []
            abstractors.reserveCapacity(graphs.count)
        var _extensions:[[Extension]] = []
            _extensions.reserveCapacity(graphs.count)
        
        var beliefs:Beliefs = .init() 

        for graph:SymbolGraph in graphs 
        {
            let module:Tree.Position<Module> = self[index].tree[branch].add(module: graph.id, 
                culture: index, 
                fasces: fasces) 
            // use this instead of `graph.id` to prevent string duplication
            var namespaces:Namespaces = .init(id: self[global: module].id, 
                position: module, 
                _branch: branch)
            var fasces:[Fascis] = fasces 
            // add explicit dependencies 
            for dependency:SymbolGraph.Dependency in graph.dependencies
            {
                // will return an empty array if these are local dependencies, so we 
                // won’t accidentally capture the buffer we are trying to modify!
                fasces.append(contentsOf: try namespaces.link(package: dependency.package, 
                    dependencies: dependency.modules, 
                    linkable: linkable, 
                    context: self))
            }
            // add implicit dependencies
            switch self[module.package].kind
            {
            case .community(_): 
                fasces.append(contentsOf: try namespaces.link(package: .core, 
                    linkable: linkable, 
                    context: self))
                fallthrough 
            case .core: 
                fasces.append(contentsOf: try namespaces.link(package: .swift, 
                    linkable: linkable, 
                    context: self))
            case .swift: 
                break 
            }

            // all of the fasces in `fasces` are from different branches, 
            // so this will not cause copy-on-write.
            let (abstractor, _rendered):(_Abstractor, [Extension]) = self[index].tree[branch].add(graph: graph, 
                namespaces: namespaces, 
                fasces: fasces, 
                stems: &stems) 

            beliefs.update(with: graph.edges, abstractor: abstractor, context: self)

            targets.append(namespaces)
            abstractors.append(abstractor)
            _extensions.append(_rendered)
        }

        beliefs.integrate()

        // successfully registered symbolgraph contents 
        let revision:_Version.Revision = self.commit(pin.revision, to: branch, of: index, 
            pins: targets.reduce(into: [:]) 
            { 
                $0.merge($1.pins) { $1 } 
            })

        // we must compute the entire cohort before performing any writes, 
        // to avoid copy-on-write.
        let cohort:Route.Cohort = .init(beliefs: beliefs, context: self)
        self[index].tree[branch].routes.stack(routes: cohort.naturals, 
            revision: revision)
        self[index].tree[branch].routes.stack(routes: cohort.synthetics.joined(), 
            revision: revision)

        // we need to recollect the upstream fasces because we (potentially) wrote 
        // to them during the call to ``commit(_:to:of:pins:)``.
        // we also cannot allow ``Namespaces.lens(local:context:)`` to retain a reference 
        // to `self[index].tree[branch].routes` until after we have added all the routes 
        // in the current cohort.
        let lenses:[Lens] = (_move targets).map { $0.lens(local: fasces, context: self) }

        self[index].tree[branch].inferScopes(&beliefs, lenses: lenses, stems: stems)
        // write to the keyframe buffers
        self[index].pushBeliefs(_move beliefs)
        // for scope:Module.Scope in scopes
        // {
        //     self[index].pushDependencies(scope.dependencies(), culture: scope.culture)
        // }
        // for (scope, articles):(Module.Scope, [Article.Index: Extension]) in zip(scopes, articles)
        // {
        //     self[index].pushExtensionMetadata(articles: articles, culture: scope.culture)
        // }
        // for (graph, abstractor):(SymbolGraph, Abstractor) in zip(graphs, abstractors)
        // {
        //     self[index].pushDeclarations(graph.declarations(abstractor: abstractor))
        //     self[index].pushToplevel(filtering: abstractor.updates)
        // }


        // self.spread(from: index, beliefs: beliefs)

        // let compiled:[Ecosystem.Index: DocumentationNode] = self.compile(
        //     comments: graphs.generateComments(abstractors: abstractors),
        //     extensions: extensions,
        //     articles: articles,
        //     scopes: scopes,
        //     pins: pins)
        // 
        // self[index].pushDocumentation(compiled)

        return index
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
        -> _Version.Revision
    {
        let version:_Version = self[index].tree[branch].commit(revision, pins: pins)
        for (package, pin):(Package.Index, _Version) in pins
        {
            assert(package != index)
            self[package].tree[pin].consumers[index, default: []].insert(version)
        }
        return version.revision
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
