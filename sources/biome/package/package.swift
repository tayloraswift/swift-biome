import Resource
import Grammar

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
    let index:Index 
    // private 
    // var tag:Resource.Tag?
    private(set) 
    var modules:CulturalBuffer<Module.Index, Module>, 
        symbols:CulturalBuffer<Symbol.Index, Symbol>,
        articles:CulturalBuffer<Article.Index, Article>
    private 
    var dependencies:Keyframe<Module.Dependencies>.Buffer, 
        declarations:Keyframe<Symbol.Declaration>.Buffer, 
        relationships:Keyframe<Symbol.Relationships>.Buffer,
        documentation:Keyframe<_Documentation>.Buffer
        
    private(set)
    var lens:LexicalLens
    
    var name:String 
    {
        self.id.string
    }
    
    init(id:ID, index:Index)
    {
        self.id = id 
        self.index = index
        
        // self.tag = "2.0.0"
        self.lens = .init()
        self.modules = .init()
        self.symbols = .init()
        self.articles = .init()
        
        self.dependencies = .init()
        self.declarations = .init()
        self.relationships = .init()
        self.documentation = .init()
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
    
    func scope(_ culture:Module.Index, at version:Version, given ecosystem:Ecosystem) 
        -> Symbol.Scope
    {
        let module:Module = self[local: culture]
        guard let dependencies:Module.Dependencies = 
            self.dependencies.at(version, head: module.heads.dependencies)
        else 
        {
            fatalError("unreachable")
        }
        
        var scope:Symbol.Scope = .init(namespaces: .init(module))
        for module:Module.Index in dependencies.modules 
        {
            scope.namespaces.insert(self[module] ?? ecosystem[module])
        }
        for package:Index in dependencies.packages
        {
            assert(package != self.index)
            scope.lenses.append(ecosystem[package].symbols.indices)
        }
        return scope
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
    mutating 
    func update(to version:Version, with graphs:[Module.Graph], 
        given ecosystem:Ecosystem, keys:inout Route.Keys) 
        throws -> [Index: [Symbol.Index: [Symbol.Trait]]]
    {
        let cultures:[Module.Index] = 
            try self.update(modules: graphs, to: version, given: ecosystem)
        
        var scopes:[Symbol.Scope] = cultures.map 
        { 
            self.scope($0, at: version, given: ecosystem) 
        }
        
        let frames:[[Symbol.Index: Vertex.Frame]] = 
            self.update(symbols: graphs, scopes: scopes, keys: &keys)
        // add the newly-registered symbols to each module scope 
        for scope:Int in scopes.indices
        {
            scopes[scope].lenses.append(self.symbols.indices)
        }
        
        // extract doccomments 
        var documentation:[[Symbol.Index: String]] = 
            frames.map { $0.compactMapValues(\.documentation) }
        
        print("(\(self.id)) found comments for \(documentation.reduce(0) { $0 + $1.count }) symbols")
        
        // resolve symbol declarations
        let declarations:[[Symbol.Index: Symbol.Declaration]] = 
            try zip(_move(frames), scopes).map 
        {
            (module:(frames:[Symbol.Index: Vertex.Frame], scope:Symbol.Scope)) in 
            try module.frames.mapValues { try .init($0, given: module.scope) }
        }
        // resolve edge statements 
        let (statements, sponsorships):([[Symbol.Statement]], [Symbol.Sponsorship]) = 
            try self.statements(zip(graphs, scopes), given: ecosystem)
        // compute relationships
        let ideologies:[Module.Index: Module.Beliefs] = try self.beliefs(_move(statements), 
            about: declarations.map(\.keys),
            cultures: cultures)
        
        // defer the merge until the end to reduce algorithmic complexity
        self.lens.merge(self.lens(ideologies, given: ecosystem, keys: &keys))
        
        print("(\(self.id)) found \(self.lens.count) addressable endpoints")
        
        // apply declaration updates 
        for (symbol, declaration):(Symbol.Index, Symbol.Declaration) in 
            _move(declarations).joined() 
        {
            self.declarations.update(head: &self.symbols[local: symbol].heads.declaration, 
                to: version, with: declaration)
        }
        // apply relationship updates 
        for (symbol, relationships):(Symbol.Index, Symbol.Relationships) in 
            ideologies.values.map(\.facts).joined()
        {
            self.relationships.update(head: &self.symbols[local: symbol].heads.relationships, 
                to: version, with: relationships)
        }
        
        // merge opinions into a single dictionary
        let opinions:[Index: [Symbol.Index: [Symbol.Trait]]] = 
            _move(ideologies).values.reduce(into: [:])
        {
            $0.merge($1.opinions) { $0.merging($1, uniquingKeysWith: + ) }
        }
        
        // gather documentation extensions 
        let articles:[[Extension]] = graphs.map 
        { 
            $0.articles.filter { $0.binding == nil } 
        }
        let extensions:[[(String, Extension)]] = graphs.map 
        { 
            $0.articles.compactMap 
            { 
                (article:Extension) in article.binding.map { ($0, article) } 
            } 
        }
        let bindings:[[Link.UniqueResolution: Extension]] = try self.bind(
            zip(_move(extensions), scopes.map(\.namespaces)), given: ecosystem, keys: keys)
        
        print(bindings)
        /* for (index, comment):(Symbol.Index, String) in documentation.joined()
        {

        } */
        return opinions
    }
    
    
    /* func _select<Path>(global link:Link.Reference<Path>, 
        given ecosystem:Ecosystem, keys:Route.Keys)
        throws -> Link.Resolution?
        where Path:BidirectionalCollection, Path.Element == Link.Component
    {
        let local:Link.Reference<Path.SubSequence>
        let nation:Self, 
            implicit:Bool
        if  let package:ID = link.nation, 
            let package:Self = self.id == package ? self : ecosystem[package]
        {
            implicit = false
            nation = package 
            local = link.dropFirst()
        }
        else if let swift:Self = ecosystem[.swift]
        {
            implicit = true
            nation = swift
            local = link[...]
        }
        else 
        {
            return nil
        }
        guard let namespace:Module.ID = local.namespace 
        else 
        {
            return implicit ? nil : .one(.package(nation.index))
        }
        guard let namespace:Module.Index = nation.modules.indices[namespace]
        else 
        {
            return nil
        }
        
        // determine which package contains the actual symbol documentation; 
        // it may be different from the nation 
        if  let culture:ID = link.query.culture, 
            let culture:Self = self.id == culture ? self : ecosystem[culture]
        {
            return try culture.lens.select(namespace, [], local.dropFirst(), keys: keys)
        }
        else 
        {
            return try  nation.lens.select(namespace, [], local.dropFirst(), keys: keys)
        }
    } */
    

    private mutating 
    func update(modules graphs:[Module.Graph], to version:Version, given ecosystem:Ecosystem) 
        throws -> [Module.Index]
    {
        // create modules, if they do not exist already.
        // note: module indices are *not* necessarily contiguous, 
        // or even monotonically increasing
        let cultures:[Module.Index] = graphs.map 
        { 
            self.insert(module: $0.core.namespace) 
        }
        // resolve dependencies
        let dependencies:[Module.Dependencies] = 
            try self.dependencies(zip(cultures, graphs), given: ecosystem)
        
        // apply dependency updates
        for (culture, dependencies):(Module.Index, Module.Dependencies) in 
            zip(cultures, _move(dependencies))
        {
            self.dependencies.update(head: &self.modules[local: culture].heads.dependencies, 
                to: version, with: dependencies)
        }
        
        return cultures
    }
    private mutating 
    func insert(module:Module.ID) -> Module.Index
    {
        self.modules.insert(module, culture: self.index, Module.init(id:index:))
    }
    
    private mutating 
    func update(symbols graphs:[Module.Graph], scopes:[Symbol.Scope], keys:inout Route.Keys) 
        -> [[Symbol.Index: Vertex.Frame]]
    {
        let extant:Int = self.symbols.count
        
        var updated:Int = 0 
        var frames:[[Symbol.Index: Vertex.Frame]] = []
            frames.reserveCapacity(graphs.count)
        for (graph, scope):(Module.Graph, Symbol.Scope) in zip(graphs, scopes)
        {
            let updates:[Symbol.Index: Vertex.Frame] = 
                self.insert(symbols: graph, scope: scope, keys: &keys)
            frames.append(updates)
            updated += updates.count
        }
        
        print("(\(self.id)) updated \(updated) symbols (\(self.symbols.count - extant) are new)")
        return frames
    }
    private mutating 
    func insert(symbols graph:Module.Graph, scope:Symbol.Scope, keys:inout Route.Keys) 
        -> [Symbol.Index: Vertex.Frame]
    {            
        var updates:[Symbol.Index: Vertex.Frame] = [:]
        for colony:Module.Subgraph in [[graph.core], graph.colonies].joined()
        {
            // will always succeed for the core subgraph
            guard let namespace:Module.Index = scope.namespaces[colony.namespace]
            else 
            {
                print("warning: ignored colonial symbolgraph '\(graph.core.namespace)@\(colony.namespace)'")
                print("note: '\(colony.namespace)' is not a known dependency of '\(graph.core.namespace)'")
                continue 
            }
            
            let offset:Int = self.symbols.count
            for (id, vertex):(Symbol.ID, Vertex) in colony.vertices 
            {
                if scope.contains(id) 
                {
                    // usually happens because of inferred symbols. ignore.
                    continue 
                }
                let index:Symbol.Index = self.symbols.insert(id, culture: scope.culture)
                {
                    (id:Symbol.ID, _:Symbol.Index) in 
                    let stem:[String] = .init(vertex.path.dropLast())
                    let leaf:String = vertex.path[vertex.path.endIndex - 1]
                    let route:Route = .init(namespace, 
                              keys.register(components: stem), 
                        .init(keys.register(component:  leaf), 
                        orientation: vertex.color.orientation))
                    return .init(id: id, nest: stem, name: leaf, color: vertex.color, route: route)
                }
                
                updates[index] = vertex.frame
            }
            
            self.modules[local: scope.culture].matrix.append(Symbol.ColonialRange.init(
                namespace: namespace, offsets: offset ..< self.symbols.count))
        }
        return updates
    }
    
    private 
    func bind<Modules>(_ modules:Modules, given ecosystem:Ecosystem, keys:Route.Keys) 
        throws -> [[Link.UniqueResolution: Extension]]
        where Modules:Sequence, Modules.Element == ([(String, Extension)], Module.Scope)
    {
        try modules.map 
        {
            // build a lexical scope for the bindings. it should contain *all* our 
            // available namespaces, but only *one* lens.
            let scope:LexicalScope = .init(namespaces: $0.1, lenses: [self.lens], keys: keys)
            var extensions:[Link.UniqueResolution: Extension] = [:]
            for (binding, article):(String, Extension) in $0.0
            {
                let expression:Link.Expression = try Link.Expression.init(relative: binding)
                let binding:Link.Resolution? = scope.resolve(visible: expression.reference)
                {
                    self[$0] ?? ecosystem[$0]
                }
                switch binding
                {
                case .many(_)?, nil: 
                    fatalError("unimplemented")
                case .one(let unique)?:
                    // TODO: emit warning for colliding extensions
                    extensions[unique] = article 
                }
            }
            return extensions
        }
    }
    
    private 
    func lens(_ ideologies:[Module.Index: Module.Beliefs], 
        given ecosystem:Ecosystem, keys:inout Route.Keys)
         -> LexicalLens
    {
        var lens:LexicalLens = .init()
        for (culture, beliefs):(Module.Index, Module.Beliefs) in ideologies 
        {
            for (host, relationships):(Symbol.Index, Symbol.Relationships) in beliefs.facts
            {
                let symbol:Symbol = self[local: host]
                
                lens.insert(natural: (host, symbol.route))
                
                let features:[(perpetrator:Module.Index?, features:[Symbol.Index])] = 
                    relationships.features(assuming: symbol.color)
                if  features.isEmpty
                {
                    continue 
                }
                // don’t register the complete host path unless we have at 
                // least one feature!
                let path:Route.Stem = keys.register(complete: symbol)
                for (perpetrator, features):(Module.Index?, [Symbol.Index]) in features 
                {
                    lens.insert(perpetrator: perpetrator ?? culture, 
                        victim: (host, symbol.namespace, path), 
                        features: features.map 
                        { 
                            ($0, (self[$0] ?? ecosystem[$0]).route.leaf) 
                        })
                }
            }
            for (host, traits):(Symbol.Index, [Symbol.Trait]) in beliefs.opinions.values.joined()
            {
                let features:[Symbol.Index] = traits.compactMap(\.feature) 
                if !features.isEmpty
                {
                    let symbol:Symbol = ecosystem[host]
                    let path:Route.Stem = keys.register(complete: symbol)
                    lens.insert(perpetrator: culture, 
                        victim: (host, symbol.namespace, path), 
                        features: features.map 
                        {
                            ($0, (self[$0] ?? ecosystem[$0]).route.leaf)
                        })
                }
            }
        }
        return lens
    }
}
