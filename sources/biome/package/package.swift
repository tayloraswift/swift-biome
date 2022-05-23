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
    var modules:CulturalBuffer<Module.Index, Module>, 
        symbols:CulturalBuffer<Symbol.Index, Symbol>
    private 
    var dependencies:Keyframe<Module.Dependencies>.Buffer, 
        declarations:Keyframe<Symbol.Declaration>.Buffer, 
        relationships:Keyframe<Symbol.Relationships>.Buffer
        
    private 
    var table:[Symbol.Key: Symbol.Group]
    
    var name:String 
    {
        self.id.string
    }
    
    init(id:ID, index:Index)
    {
        self.id = id 
        self.index = index
        
        // self.tag = "2.0.0"
        self.table = [:]
        self.modules = .init()
        self.symbols = .init()
        
        self.dependencies = .init()
        self.declarations = .init()
        // self.documentation = .init()
        self.relationships = .init()
    }

    subscript(local module:Module.Index) -> Module 
    {
        _read 
        {
            yield self.modules[local: module]
        }
    }
    subscript(local symbol:Symbol.Index) -> Symbol
    {
        _read 
        {
            yield self.symbols[local: symbol]
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
    
    subscript(local module:Module.Index, at version:Version) 
        -> (module:Module, dependencies:Module.Dependencies)
    {
        fatalError("unimplemented")
    }
    
    mutating 
    func update(with opinions:[Symbol.Index: [Symbol.Trait]], from package:Index)
    {
        for (symbol, traits):(Symbol.Index, [Symbol.Trait]) in opinions 
        {
            self.symbols[local: symbol].update(traits: traits, from: package)
        }
    }
}

extension Package 
{
    private mutating 
    func create(modules graphs:[Module.Graph], version:Version, given ecosystem:Ecosystem) 
        throws -> [Module.Index]
    {
        // first pass: create module entries
        let cultures:[Module.Index] = graphs.map 
        {
            self.modules.insert($0.core.namespace, culture: self.index, Module.init(id:index:))
        }
        // second pass: apply module updates
        for (culture, graph):(Module.Index, Module.Graph) in zip(cultures, graphs)
        {
            var dependencies:Module.Dependencies = try self.resolve(graph.dependencies, 
                given: ecosystem)
            // add self-import, if not already present 
            dependencies.modules.insert(culture)
            
            self.dependencies.update(head: &self.modules[local: culture].head.dependencies, 
                to: version, with: dependencies)
        }
        return cultures
    }
    private 
    func resolve(_ dependencies:[Module.Graph.Dependency], given ecosystem:Ecosystem) 
        throws -> Module.Dependencies
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
        
        var modules:Set<Module.Index> = []
        var packages:Set<Package.Index> = []
        for (id, imports):(ID, [Module.ID]) in dependencies 
        {
            let package:Self 
            if self.id == id
            {
                package = self 
            }
            else if let upstream:Package = ecosystem[id]
            {
                package = upstream
                packages.insert(upstream.index)
            }
            else 
            {
                throw Package.ResolutionError.dependency(id, of: self.id)
            }
            
            for id:Module.ID in imports
            {
                guard let index:Module.Index = package.modules.indices[id]
                else 
                {
                    throw Module.ResolutionError.target(id, in: package.id)
                }
                modules.insert(index)
            }
        }
        return .init(packages: packages, modules: modules)
    }
    mutating 
    func update(to version:Version, with graphs:[Module.Graph], 
        given ecosystem:Ecosystem, keys:inout Symbol.Key.Table) 
        throws -> [Index: [Symbol.Index: [Symbol.Trait]]]
    {
        // note: module indices are *not* necessarily contiguous, 
        // or even monotonically increasing
        
        let cultures:[Module.Index] = try self.create(modules: graphs, 
            version: version, given: ecosystem)
        
        var scopes:[Scope] = cultures.map 
        {
            let dependencies:Module.Dependencies = self[local: $0, at: version].dependencies
            
            var scope:Scope = .init()
            for module:Module.Index in dependencies.modules 
            {
                scope.import(self[module] ?? ecosystem[module])
            }
            for package:Index in dependencies.packages
            {
                scope.append(lens: ecosystem[package].symbols.indices)
            }
            return scope
        }
        
        let updates:[[Symbol.Index: Vertex.Frame]] = zip(cultures, zip(graphs, scopes)).map
        {
            self.extend($0.0, with: $0.1.0, scope: $0.1.1, keys: &keys)
        }
        // add the newly-registered symbols to each module scope 
        for scope:Int in scopes.indices
        {
            scopes[scope].append(lens: self.symbols.indices)
        }
        
        // resolve symbol declarations
        let declarations:[[Symbol.Index: Symbol.Declaration]] = 
            try zip(_move(updates), scopes).map 
        {
            (module:(updates:[Symbol.Index: Vertex.Frame], scope:Scope)) in 
            try module.updates.mapValues { try .init($0, given: module.scope) }
        }
        // resolve edge statements 
        let (statements, sponsorships):([[Symbol.Statement]], [Symbol.Sponsorship]) = 
            try self.statements(zip(graphs, scopes), given: ecosystem)
        // compute relationships
        let (facts, opinions):([Symbol.Index: Symbol.Relationships], [Index: [Symbol.Index: [Symbol.Trait]]]) = 
            try self.relationships(zip(cultures, _move(statements)), 
                between: declarations.map(\.keys).joined())
        
        // apply declaration updates 
        for (symbol, declaration):(Symbol.Index, Symbol.Declaration) in _move(declarations).joined() 
        {
            self.declarations.update(head: &self.symbols[local: symbol].head.declaration, 
                to: version, with: declaration)
        }
        // apply relationship updates 
        for (symbol, relationships):(Symbol.Index, Symbol.Relationships) in _move(facts)
        {
            self.relationships.update(head: &self.symbols[local: symbol].head.relationships, 
                to: version, with: relationships)
        }
        
        let groups:[Symbol.Key: Symbol.Group] = self.groups(
            facts: facts, opinions: opinions.values.joined(), 
            given: ecosystem, 
            keys: &keys)
        // defer the merge until the end to reduce algorithmic complexity
        self.table.merge(_move(groups)) { $0.union($1) }
        
        return opinions
    }
    
    private mutating 
    func extend(_ culture:Module.Index, with graph:Module.Graph, scope:Scope, 
        keys:inout Symbol.Key.Table) 
        -> [Symbol.Index: Vertex.Frame]
    {            
        var updates:[Symbol.Index: Vertex.Frame] = [:]
        for colony:Module.Subgraph in [[graph.core], graph.colonies].joined()
        {
            // will always succeed for the core subgraph
            guard let namespace:Module.Index = scope[colony.namespace]
            else 
            {
                print("warning: ignored colonial symbolgraph '\(graph.core.namespace)@\(colony.namespace)'")
                print("note: '\(colony.namespace)' is not a known dependency of '\(graph.core.namespace)'")
                continue 
            }
            
            let offset:Int = self.symbols.count
            for (id, vertex):(Symbol.ID, Vertex) in colony.vertices 
            {
                guard case nil = scope[id]
                else 
                {
                    // usually happens because of inferred symbols. ignore.
                    continue 
                }
                let index:Symbol.Index = self.symbols.insert(id, culture: culture)
                {
                    (id:Symbol.ID, _:Symbol.Index) in 
                    let leaf:String = vertex.path[vertex.path.endIndex - 1]
                    let stem:[String] = .init(vertex.path.dropLast())
                    return .init(id: id, 
                        key: .init(namespace, 
                                  keys.register(components: stem), 
                            .init(keys.register(component:  leaf), 
                            orientation: vertex.color.orientation)), 
                        nest: stem, 
                        name: leaf, 
                        color: vertex.color)
                }
                
                updates[index] = vertex.frame
            }
            
            self.modules[local: culture].matrix.append(Symbol.ColonialRange.init(
                namespace: namespace, offsets: offset ..< self.symbols.count))
        }
        return updates
    }
    
    private 
    func groups<Facts, Opinions>(facts:Facts, opinions:Opinions, 
        given ecosystem:Ecosystem, keys:inout Symbol.Key.Table)
         -> [Symbol.Key: Symbol.Group]
        where   Facts:Sequence,    Facts.Element    == (key:Symbol.Index, value:Symbol.Relationships), 
                Opinions:Sequence, Opinions.Element == (key:Symbol.Index, value:[Symbol.Trait])
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
        for (symbol, relationships):(Symbol.Index, Symbol.Relationships) in facts
        {
            let victim:Symbol = self[local: symbol]
            groups[victim.key, default: .none].insert(.natural(symbol))
            if case .concretetype(_) = victim.color, 
                !relationships.facts.features.isEmpty
            {
                add(features: relationships.facts.features, to: victim, at: symbol)
            }
        }
        for (symbol, traits):(Symbol.Index, [Symbol.Trait]) in opinions
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
