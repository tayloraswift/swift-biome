/// an ecosystem is a subset of a biome containing packages that are relevant 
/// (in some user-defined way) to some task. 
/// 
/// ecosystem views are mainly useful for providing an immutable context for 
/// accessing foreign packages.
struct Ecosystem 
{
    private 
    let standardModules:[Module.ID], 
        coreModules:[Module.ID]
    
    var packages:[Package], 
        indices:[Package.ID: Package.Index]
    
    init(standardModules:[Module.ID], coreModules:[Module.ID])
    {
        self.standardModules = standardModules
        self.coreModules = coreModules
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
    /// returns the index of the entry for the given package, creating it if it 
    /// does not already exist.
    mutating 
    func create(package:Package.ID) -> Package.Index 
    {
        if let index:Package.Index = self.indices[package]
        {
            return index 
        }
        let index:Package.Index = .init(offset: self.packages.endIndex)
        self.packages.append(.init(id: package, index: index))
        self.indices[package] = index
        return index
    }
}
extension Ecosystem 
{
    func dependencies(_ local:Package, _ graphs:[Module.Graph], cultures:[Module.Index]) 
        throws -> [Set<Module.Index>]
    {
        var dependencies:[Set<Module.Index>] = []
            dependencies.reserveCapacity(cultures.count)
        for (graph, culture):(Module.Graph, Module.Index) in zip(graphs, cultures)
        {
            // remove self-dependencies 
            var set:Set<Module.Index> = try self.dependencies(local, graph.dependencies)
                set.remove(culture)
            dependencies.append(set)
        }
        return dependencies
    }
    
    private 
    func dependencies(_ local:Package, _ dependencies:[Module.Graph.Dependency]) 
        throws -> Set<Module.Index>
    {
        var dependencies:[Package.ID: [Module.ID]] = [Package.ID: [Module.Graph.Dependency]]
            .init(grouping: dependencies, by: \.package)
            .mapValues 
        {
            $0.flatMap(\.modules)
        }
        // add implicit dependencies 
            dependencies[.swift, default: []].append(contentsOf: self.standardModules)
        if local.id != .swift 
        {
            dependencies[.core,  default: []].append(contentsOf: self.coreModules)
        }
        var modules:Set<Module.Index> = []
        for (id, namespaces):(Package.ID, [Module.ID]) in dependencies 
        {
            guard let package:Package = local.id == id ? local : self[id]
            else 
            {
                throw Package.ResolutionError.dependency(id, of: local.id)
            }
            for id:Module.ID in namespaces
            {
                guard let index:Module.Index = package.modules.indices[id]
                else 
                {
                    throw Module.ResolutionError.target(id, in: package.id)
                }
                modules.insert(index)
            }
        }
        return modules
    }
}
extension Ecosystem 
{
    func statements(_ local:Package, _ graphs:[Module.Graph], scopes:[Symbol.Scope])
        throws -> (speeches:[[Symbol.Statement]], origins:[Symbol.Index: Symbol.Index])
    {
        var origins:[Symbol.Index: Symbol.Index] = [:]
        var speeches:[[Symbol.Statement]] = [] 
            speeches.reserveCapacity(scopes.count)
        for (graph, scope):(Module.Graph, Symbol.Scope) in zip(graphs, scopes)
        {
            // if we have `n` edges, we will get between `n` and `2n` statements
            var statements:[Symbol.Statement] = []
                statements.reserveCapacity(graph.edges.reduce(0) { $0 + $1.count })
            for edge:Edge in graph.edges.joined()
            {
                let constraints:[Generic.Constraint<Symbol.Index>] = 
                    try edge.constraints.map { try $0.map(scope.index(of:)) }
                let (source, target):(Symbol.Index, Symbol.Index) = 
                (
                    try scope.index(of: edge.source),
                    try scope.index(of: edge.target)
                )
                
                switch try self.statements(local, 
                    when: source, is: edge.kind, of: target, where: constraints)
                {
                case (let source?,  let target):
                    statements.append(source)
                    statements.append(target)
                case (nil,          let target):
                    statements.append(target)
                }
                
                // this fails quite frequently. we don’t have a great solution for this.
                if  let origin:Symbol.ID = edge.origin, 
                    let origin:Symbol.Index = try? scope.index(of: origin)
                {
                    origins[source] = origin
                }
            }
            speeches.append(statements)
        }
        return (speeches, origins)
    }
    
    private 
    func statements(_ local:Package, 
        when source:Symbol.Index, is label:Edge.Kind, of target:Symbol.Index, 
        where constraints:[Generic.Constraint<Symbol.Index>])
        throws -> (source:Symbol.Statement?, target:Symbol.Statement)
    {
        switch  
        (
                local[source]?.color ?? self[source].color,
            is: label,
            of: local[target]?.color ?? self[target].color,
            unconditional: constraints.isEmpty
        ) 
        {
        case    (.callable(_),      is: .feature,               of: .concretetype(_),   unconditional: true):
            return
                (
                    nil,
                    (target, .has(.feature(source)))
                )
        
        case    (.concretetype(_),  is: .member,                of: .concretetype(_),   unconditional: true), 
                (.typealias,        is: .member,                of: .concretetype(_),   unconditional: true), 
                (.callable(_),      is: .member,                of: .concretetype(_),   unconditional: true), 
                (.concretetype(_),  is: .member,                of: .protocol,          unconditional: true),
                (.typealias,        is: .member,                of: .protocol,          unconditional: true),
                (.callable(_),      is: .member,                of: .protocol,          unconditional: true):
            return 
                (
                    (source,  .is(.member(of: target))), 
                    (target, .has(.member(    source)))
                )
        
        case    (.concretetype(_),  is: .conformer,             of: .protocol,          unconditional: _):
            return 
                (
                    (source, .has(.conformance(target, where: constraints))), 
                    (target, .has(  .conformer(source, where: constraints)))
                )
         
        case    (.protocol,         is: .conformer,             of: .protocol,          unconditional: true):
            return 
                (
                    (source,  .is(.refinement(of: target))), 
                    (target, .has(.refinement(    source)))
                ) 
        
        case    (.class,            is: .subclass,              of: .class,             unconditional: true):
            return 
                (
                    (source,  .is(.subclass(of: target))), 
                    (target, .has(.subclass(    source)))
                ) 
         
        case    (.associatedtype,   is: .override,              of: .associatedtype,    unconditional: true),
                (.callable(_),      is: .override,              of: .callable,          unconditional: true):
            return 
                (
                    (source,  .is(.override(of: target))), 
                    (target, .has(.override(    source)))
                ) 
         
        case    (.associatedtype,   is: .requirement,           of: .protocol,          unconditional: true),
                (.callable(_),      is: .requirement,           of: .protocol,          unconditional: true),
                (.associatedtype,   is: .optionalRequirement,   of: .protocol,          unconditional: true),
                (.callable(_),      is: .optionalRequirement,   of: .protocol,          unconditional: true):
            return 
                (
                    (source,  .is(.requirement(of: target))), 
                    (target,  .is(  .interface(of: source)))
                ) 
         
        case    (.callable(_),      is: .defaultImplementation, of: .callable(_),       unconditional: true):
            return 
                (
                    (source,  .is(.implementation(of: target))), 
                    (target, .has(.implementation(    source)))
                ) 
        
        case (_, is: _, of: _, unconditional: false):
            // ``Edge.init(from:)`` should have thrown a ``JSON.LintingError`
            fatalError("unreachable")
        
        case (let source, is: let label, of: let target, unconditional: true):
            throw Symbol.RelationshipError.miscegenation(source, cannotBe: label, of: target)
        }
    }
}
