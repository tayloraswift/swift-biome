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
    
    public 
    let id:ID
    private 
    let index:Index 
    // private 
    // var tag:Resource.Tag?
    private 
    var buffer:Symbol.Buffer
        
    private 
    var table:[Symbol.Key: Symbol.Group]
    
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
        self.table = [:]
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
    func update(with opinions:[Symbol.Index: [Symbol.Trait]], from package:Index)
    {
        self.buffer.update(with: opinions, from: package)
    }
    
    mutating 
    func update(to version:Version, with graphs:[Module.Graph], 
        given ecosystem:Ecosystem, keys:inout Symbol.Key.Table) 
        throws -> [Index: [Symbol.Index: [Symbol.Trait]]]
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
                keys: &keys)
        }
        // add the newly-registered symbols to each module scope 
        for (scope, dependencies):(Int, Module.Node) in zip(scopes.indices, _move(dependencies))
        {
            scopes[scope].import(dependencies.local, lens: self.lens)
        }
        // apply vertex updates 
        try self.buffer.update(to: version, with: zip(scopes, updates))
        
        // second pass
        let tray:Symbol.Tray = try self.link(edges: zip(cultures, zip(scopes, graphs)),
            between: _move(updates).map(\.keys).joined(), given: ecosystem)
        
        // apply edge updates and rebuild keygroups
        let local:[Symbol.Index: [Symbol.Index]] = try self.buffer.update(to: version, with: tray.facts)
        let groups:[Symbol.Key: Symbol.Group] = self.groups(
            local: _move(local), upstream: tray.opinions.values.joined(), 
            given: ecosystem, 
            keys: &keys)
        // defer the merge until the end to reduce algorithmic complexity
        self.table.merge(_move(groups)) { $0.union($1) }
        
        return tray.opinions
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
        dependencies[.swift,    default: []].append(contentsOf: ecosystem.standardModules)
        if self.id != .swift 
        {
            dependencies[.core, default: []].append(contentsOf: ecosystem.coreModules)
        }
        
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
    private 
    func link<Edges, Vertices>(edges:Edges, between vertices:Vertices, given ecosystem:Ecosystem) 
        throws -> Symbol.Tray
        where   Vertices:Sequence, Vertices.Element == Symbol.Index, 
                Edges:Sequence,    Edges.Element == (Module.Index, (Scope, Module.Graph))
    {
        var tray:Symbol.Tray = .init(vertices)
        for (culture, (scope, graph)):(Module.Index, (Scope, Module.Graph)) in edges
        {
            for article:Extension in graph.articles 
            {
                print(article.metadata.path)
            }
            for edge:Edge in graph.edges.joined()
            {
                let (statement, secondary, sponsorship):Edge.Statements = 
                    try edge.statements(given: scope)
                {
                    self[$0]?.color ?? ecosystem[$0].color
                }
                try tray.link(statement, of: culture)
                guard let statement:Symbol.Statement = secondary
                else 
                {
                    continue 
                }
                try tray.link(statement, of: culture)
            }
        }
        return tray
    }
    private 
    func groups<Local, Upstream>(local:Local, upstream:Upstream, 
        given ecosystem:Ecosystem, keys:inout Symbol.Key.Table)
         -> [Symbol.Key: Symbol.Group]
        where   Local:Sequence, Local.Element == (key:Symbol.Index, value:[Symbol.Index]), 
                Upstream:Sequence, Upstream.Element == (key:Symbol.Index, value:[Symbol.Trait])
    {
        var groups:[Symbol.Key: Symbol.Group] = [:]
        
        func add(features:[Symbol.Index], to victim:Symbol, at index:Symbol.Index) 
        {
            let stem:Symbol.Key.Stem = keys.register(complete: victim)
            for feature:Symbol.Index in features 
            {
                // symbols can inherit things from other packages
                let witness:Symbol = self[feature] ?? ecosystem[feature]
                let key:Symbol.Key = .init(victim.namespace, stem, witness.key.leaf)
                
                groups[key, default: .none].insert(.synthesized(index, feature))
            }
        }
        for (symbol, features):(Symbol.Index, [Symbol.Index]) in local
        {
            let victim:Symbol = self[local: symbol]
            groups[victim.key, default: .none].insert(.natural(symbol))
            if !features.isEmpty
            {
                add(features: features, to: victim, at: symbol)
            }
        }
        for (symbol, traits):(Symbol.Index, [Symbol.Trait]) in upstream
        {
            let features:[Symbol.Index] = traits.compactMap(\.feature) 
            if !features.isEmpty
            {
                add(features: features, to: ecosystem[symbol], at: symbol)
            }
        }
        return groups
    }
}
