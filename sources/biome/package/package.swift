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
        
    private 
    var routes:[Route: Symbol.Group]
    
    var name:String 
    {
        self.id.string
    }
    
    init(id:ID, index:Index)
    {
        self.id = id 
        self.index = index
        
        // self.tag = "2.0.0"
        self.routes = [:]
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
        // create modules, if they do not exist already.
        // note: module indices are *not* necessarily contiguous, 
        // or even monotonically increasing
        let cultures:[Module.Index] = graphs.map { self.insert($0.core.namespace) }
        
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
        
        var scopes:[Scope] = cultures.map 
        {
            guard let dependencies:Module.Dependencies = 
                self.dependencies.at(version, head: self[local: $0].heads.dependencies)
            else 
            {
                fatalError("unreachable")
            }
            return self.scope(dependencies, given: ecosystem)
        }
        let extant:Int = self.symbols.count
        let updates:[[Symbol.Index: Vertex.Frame]] = zip(cultures, zip(graphs, scopes)).map
        {
            self.extend($0.0, with: $0.1.0, scope: $0.1.1, keys: &keys)
        }
        let updated:Int = updates.reduce(0) { $0 + $1.count }
        print("(\(self.id)) updated \(updated) symbols (\(self.symbols.count - extant) are new)")
        
        // add the newly-registered symbols to each module scope 
        for scope:Int in scopes.indices
        {
            scopes[scope].append(lens: self.symbols.indices)
        }
        
        // extract doccomments 
        var documentation:[[Symbol.Index: String]] = 
            updates.map { $0.compactMapValues(\.documentation) }
        
        print("(\(self.id)) found comments for \(documentation.reduce(0) { $0 + $1.count }) of \(updated) symbols")
        
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
            self.declarations.update(head: &self.symbols[local: symbol].heads.declaration, 
                to: version, with: declaration)
        }
        // apply relationship updates 
        for (symbol, relationships):(Symbol.Index, Symbol.Relationships) in _move(facts)
        {
            self.relationships.update(head: &self.symbols[local: symbol].heads.relationships, 
                to: version, with: relationships)
        }
        
        let groups:[Route: Symbol.Group] = self.groups(
            facts: facts, opinions: opinions.values.joined(), 
            given: ecosystem, 
            keys: &keys)
        print("(\(self.id)) found \(groups.count) addressable endpoints")
        // defer the merge until the end to reduce algorithmic complexity
        self.routes.merge(_move(groups)) { $0.union($1) }
        
        // gather documentation extensions 
        for (index, (graph, scope)):(Int, (Module.Graph, Scope)) in 
            zip(documentation.indices, zip(graphs, scopes))
        {
            for article:Extension in graph.articles 
            {
                if let binding:Link.Expression = try article.binding.map(Link.Expression.init(relative:))
                {
                    // check if the first component refers to a module. it can be the same 
                    // as its own culture, or one of its dependencies. 
                    let namespace:Module.Index
                    let local:Link.Reference<ArraySlice<Link.Component>>
                    if  let id:Module.ID = binding.reference.module,
                        let explicit:Module.Index = scope[id]
                    {
                        namespace = explicit
                        local = binding.reference.dropFirst()
                        
                    }
                    else 
                    {
                        local = binding.reference[...]
                    }
                }
                else 
                {
                    
                }
            }
        }
        
        return opinions
    }
    
    private mutating 
    func insert(_ module:Module.ID) -> Module.Index
    {
        self.modules.insert(module, culture: self.index, Module.init(id:index:))
    }
    
    private mutating 
    func extend(_ culture:Module.Index, with graph:Module.Graph, scope:Scope, keys:inout Route.Keys) 
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
            
            self.modules[local: culture].matrix.append(Symbol.ColonialRange.init(
                namespace: namespace, offsets: offset ..< self.symbols.count))
        }
        return updates
    }
    
    private 
    func groups<Facts, Opinions>(facts:Facts, opinions:Opinions, 
        given ecosystem:Ecosystem, keys:inout Route.Keys)
         -> [Route: Symbol.Group]
        where   Facts:Sequence,    Facts.Element    == (key:Symbol.Index, value:Symbol.Relationships), 
                Opinions:Sequence, Opinions.Element == (key:Symbol.Index, value:[Symbol.Trait])
    {
        var groups:[Route: Symbol.Group] = [:]
        
        func add(features:[Symbol.Index], to victim:Symbol, at index:Symbol.Index) 
        {
            let stem:Route.Stem = keys.register(complete: victim)
            for feature:Symbol.Index in features 
            {
                // symbols can inherit things from other packages
                let witness:Symbol = self[feature] ?? ecosystem[feature]
                let route:Route = .init(victim.namespace, stem, witness.route.leaf)
                
                groups[route, default: .none].insert(.synthesized(index, feature))
            }
        }
        for (symbol, relationships):(Symbol.Index, Symbol.Relationships) in facts
        {
            let victim:Symbol = self[local: symbol]
            groups[victim.route, default: .none].insert(.natural(symbol))
            
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

extension Package 
{
    private 
    func resolve<Path>(
        _ namespace:Module.Index, 
        _ nest:[String] = [], 
        _ link:Link.Reference<Path>, 
        keys:Route.Keys) 
        throws -> Link.Resolution?
        where Path:BidirectionalCollection, Path.Element == Link.Component
    {
        let path:[String] = nest.isEmpty ? 
            link.path.compactMap(\.prefix) : nest + link.path.compactMap(\.prefix)
        
        guard let last:String = path.last 
        else 
        {
            return .module(namespace)
        }
        guard   let stem:Route.Stem = keys[stem: path.dropLast()],
                let leaf:Route.Stem = keys[leaf: last]
        else 
        {
            return nil
        }
        
        let group:Symbol.Group
        if  let exact:Symbol.Group = 
            self.routes[.init(namespace, stem, leaf, orientation: link.orientation)]
        {
            group = exact 
        }
        else if case .straight = link.orientation, 
            let closeted:Symbol.Group = 
            self.routes[.init(namespace, stem, leaf, orientation: .gay)]
        {
            group = closeted
        }
        else 
        {
            return nil
        }
        
        switch group 
        {
        case .none: 
            fatalError("unreachable")
        case .one(let pair): 
            return .unambiguous(pair)
        case .many(let pairs):
            let disambiguator:Link.Disambiguator = .init(
                suffix: link.path.last?.suffix ?? nil,
                victim: link.query.victim,
                symbol: link.query.symbol)
            return .ambiguous(pairs, disambiguator)
        }
    }
}
