import Resource

public 
struct Package:Identifiable, Sendable
{
    /// A globally-unique index referencing a package. 
    struct Index:Hashable, Sendable 
    {
        let bits:UInt16
        
        var offset:Int 
        {
            .init(self.bits)
        }
        init(offset:Int)
        {
            self.bits = .init(offset)
        }
    }
    
    typealias Opinion = (symbol:Symbol.Index, has:Symbol.Trait)
    
    public 
    let id:ID
    private 
    let index:Index 
    // private 
    // var tag:Resource.Tag?
    private 
    var buffer:Symbol.Buffer
        
    private 
    var groups:[Symbol.Key: Symbol.Group]
    
    var name:String 
    {
        self.id.string
    }
    
    var lens:[Symbol.ID: Symbol.Index]
    {
        self.buffer.lens
    }
    
    init(id:ID, index:Index)
    {
        self.id = id 
        self.index = index
        
        // self.tag = "2.0.0"
        self.groups = [:]
        self.buffer = .init()
    }

    subscript(local module:Module.Index) -> Module 
    {
        _read 
        {
            yield self.buffer[local: module]
        }
    }
    subscript(local symbol:Symbol.Index) -> Symbol
    {
        _read 
        {
            yield self.buffer[local: symbol]
        }
    }
    
    subscript(module:Module.Index) -> Module?
    {
        self.index ==        module.package ? self[local: module] : nil
    }
    subscript(symbol:Symbol.Index) -> Symbol?
    {
        self.index == symbol.module.package ? self[local: symbol] : nil
    }
    
    mutating 
    func update(with opinions:[Opinion], from package:Index)
    {
        var traits:[Symbol.Index: [Symbol.Trait]] = [:]
        for (symbol, trait):(Symbol.Index, Symbol.Trait) in opinions 
        {
            traits[symbol, default: []].append(trait)
        }
        self.buffer.update(with: traits, from: package)
    }
    
    mutating 
    func update(with graphs:[Module.Graph], given ecosystem:Ecosystem, paths:inout PathTable) 
        throws -> [Index: [Opinion]]
    {
        // *not* necessarily contiguous, or even monotonically increasing
        let cultures:[Module.Index] = graphs.map 
        {
            self.buffer.create(module: $0.core.namespace, in: self.index)
        }
        let dependencies:[Module.Node] = try zip(graphs, cultures).map 
        {
            try self.resolve(dependencies: $0.0.dependencies, of: $0.1, given: ecosystem)
        }
        // first pass, register symbols and construct scopes containing 
        // *upstream* packages only
        var scopes:[Scope] = dependencies.map { $0.upstream(given: ecosystem) }
        let updates:[[Symbol.Index: Vertex.Frame]] = 
            try zip(cultures, zip(dependencies, zip(scopes, graphs))).map
        {
            let (culture, (node, (scope, graph))):(Module.Index, (Module.Node, (Scope, Module.Graph))) = $0
            //  all of a module’s dependencies have unique names, so build a lookup 
            //  table for them. this lookup table enables this function to 
            //  run in quadratic time; otherwise it would be cubic!
            print("(\(self.id)) adding module '\(self[local: culture].id)'")
            
            return try self.buffer.extend(with: graph, of: culture, upstream: scope,
                namespaces: node.namespaces(given: ecosystem, local: self),
                paths: &paths)
        }
        // add the newly-registered symbols to each module scope 
        for (scope, dependencies):(Int, Module.Node) in zip(scopes.indices, _move(dependencies))
        {
            scopes[scope].import(dependencies.local, lens: self.lens)
        }
        // apply vertex updates 
        try self.buffer.update(with: zip(scopes, updates))
        
        // second pass
        var tray:Symbol.Tray = .init(_move(updates).map(\.keys).joined())
        var opinions:[Index: [Opinion]] = [:]
        for (culture, (scope, graph)):(Module.Index, (Scope, Module.Graph)) in 
            zip(cultures, zip(scopes, graphs))
        {
            for edge:Edge in graph.edges.joined()
            {
                let (statement, secondary, sponsorship):Edge.Statements = 
                    try edge.statements(given: scope)
                {
                    self[$0]?.color ?? ecosystem[$0].color
                }
                if  case let (foreign, has: trait)? = try tray.link(statement, of: culture)
                {
                    opinions[foreign.module.package, default: []].append((foreign, has: trait))
                }
                if  let statement:Symbol.Statement = secondary, 
                    case let (foreign, has: trait)? = try tray.link(statement, of: culture)
                {
                    opinions[foreign.module.package, default: []].append((foreign, has: trait))
                }
            }
        }
        
        // apply edge updates 
        try self.buffer.update(with: tray.nodes)
        return opinions
    }
    
    private 
    func resolve(dependencies:[Module.Graph.Dependency], of culture:Module.Index, 
        given ecosystem:Ecosystem) throws -> Module.Node
    {
        var dependencies:[ID: [Module.ID]] = [ID: [Module.Graph.Dependency]]
            .init(grouping: dependencies, by: \.package)
            .mapValues 
        {
            $0.flatMap(\.modules)
        }
        // add implicit dependencies 
        dependencies[.swift,  default: []].append(contentsOf: ecosystem.standardModules)
        dependencies[.core,   default: []].append(contentsOf: ecosystem.coreModules)
        
        let local:[Module.ID] = dependencies.removeValue(forKey: self.id) ?? []
        let upstream:[[Module.Index]] = try dependencies.map
        {
            guard let package:Self = ecosystem[$0.key]
            else 
            {
                throw Package.ResolutionError.dependency($0.key, of: self.id)
            }
            return try $0.value.map(package.index(of:))
        }
        // add self-import, if not already present 
        return .init(local: ([culture] as Set).union(try local.map(self.index(of:))), 
            upstream: .init(upstream.joined()))
    }
    private 
    func index(of module:Module.ID) throws -> Module.Index 
    {
        if let index:Module.Index = self.buffer.index(of: module)
        {
            return index 
        }
        else 
        {
            throw Module.ResolutionError.target(module, in: self.id)
        }
    }
}
