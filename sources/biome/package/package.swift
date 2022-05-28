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
    var dependencies:Keyframe<Set<Module.Index>>.Buffer, 
        declarations:Keyframe<Symbol.Declaration>.Buffer, 
        relationships:Keyframe<Symbol.Relationships>.Buffer,
        documentation:Keyframe<_Documentation>.Buffer
        
    private(set)
    var lens:Lexicon.Lens
    
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
        guard let dependencies:Set<Module.Index> = 
            self.dependencies.at(version, head: module.heads.dependencies)
        else 
        {
            fatalError("unreachable")
        }
        var scope:Module.Scope = .init(module)
        for module:Module.Index in dependencies 
        {
            scope.insert(self[module] ?? ecosystem[module])
        }
        return .init(namespaces: scope, 
            lenses: scope.lenses(given: ecosystem, \.symbols.indices))
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

/* struct Documentation 
{
    enum Comment 
    {
        case linked(Link.UniqueResolution)
        case attached(String)
        case external(Extension)
    }
    
    var symbol:[Link.UniqueResolution: Comment]
} */
extension Package 
{
    struct Sources 
    {
        private 
        let modules:[[Symbol.Index: Vertex.Frame]]
        
        init(modules:[[Symbol.Index: Vertex.Frame]])
        {
            self.modules = modules
        }
        
        func declarations(scopes:[Symbol.Scope]) throws -> [[Symbol.Index: Symbol.Declaration]]
        {
            var declarations:[[Symbol.Index: Symbol.Declaration]] = []
                declarations.reserveCapacity(self.modules.count)
            for (frames, scope):([Symbol.Index: Vertex.Frame], Symbol.Scope) in 
                zip(self.modules, scopes)
            {
                let module:[Symbol.Index: Symbol.Declaration] = try frames.mapValues 
                { 
                    try .init($0, scope: scope) 
                }
                declarations.append(module)
            }
            return declarations
        }
        func documentation() -> [[Symbol.Index: String]]
        {
            self.modules.map { $0.compactMapValues(\.documentation) }
        }
    }
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
        
        let sources:Sources = self.update(symbols: graphs, scopes: scopes, keys: &keys)
        
        // let frames:[[Symbol.Index: Vertex.Frame]] = 
        //     self.update(symbols: graphs, scopes: scopes, keys: &keys)
        // add the newly-registered symbols to each module scope 
        for scope:Int in scopes.indices
        {
            scopes[scope].lenses.append(self.symbols.indices)
        }
        
        // resolve symbol declarations, extract doccomments 
        let comments:[[Symbol.Index: String]] = sources.documentation()
        let declarations:[[Symbol.Index: Symbol.Declaration]] = 
            try sources.declarations(scopes: scopes)
        
        let _ = _move(sources)
        
        print("(\(self.id)) found comments for \(comments.count) symbols")
        
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
        
        // merge opinions into a single dictionary
        let opinions:[Index: [Symbol.Index: [Symbol.Trait]]] = 
            ideologies.values.reduce(into: [:])
        {
            $0.merge($1.opinions) { $0.merging($1, uniquingKeysWith: + ) }
        }
        
        // apply versioned updates
        self.update(declarations:  _move(declarations),                   to: version)
        self.update(relationships: _move(ideologies).values.map(\.facts), to: version)
        
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
        //  build lexical scopes for each module culture 
        let lexica:[Lexicon] = scopes.map 
        {
            var lexicon:Lexicon = .init(keys: keys, namespaces: $0.namespaces, 
                lenses: $0.namespaces.lenses(given: ecosystem, \.lens))
            //  add the local lens 
            lexicon.lenses.append(self.lens)
            return lexicon
        }
        //  always import the standard library
        let stdlib:Set<Module.Index> = self.stdlib(given: ecosystem)
        
        for (lexicon, comments):(Lexicon, [Symbol.Index: String]) in 
            zip(lexica, _move(comments))
        {
            for (symbol, comment):(Symbol.Index, String) in comments
            {
                let comment:Extension = .init(markdown: comment)
                
                var imports:Set<Module.Index> = stdlib 
                for module:Module.ID in comment.metadata.imports
                {
                    if let module:Module.Index = lexicon.namespaces[module]
                    {
                        imports.insert(module)
                    }
                }
                let unresolved:Article.Template<String> = comment.render()
                let resolved:Article.Template<Link> = unresolved.map 
                {
                    // must attempt to parse absolute first, otherwise 
                    // '/foo' will parse to ["", "foo"]
                    if let global:Link.Expression = try? .init(absolute: $0)
                    {
                        print("global", $0)
                    }
                    else if let link:Link.Expression = try? .init(relative: $0)
                    {
                        let resolution:Link.Resolution? = lexicon.resolve(
                            visible: link.reference, imports: imports,
                            context: self[local: symbol])
                        {
                            self[$0] ?? ecosystem[$0]
                        }
                        switch resolution
                        {
                        case nil:
                            print("FAILURE", $0)
                            print("note: location is \(self[symbol] ?? ecosystem[symbol])")
                            
                        case .one(.symbol(let symbol))?:
                            print("SUCCESS", $0, "->", self[symbol] ?? ecosystem[symbol])
                        case .one(_)?: 
                            print("SUCCESS", $0, "-> (unavailable)")
                        case .many(let possibilities)?: 
                            print("AMBIGUOUS", $0)
                            for (i, possibility):(Int, Link.UniqueResolution) in possibilities.enumerated()
                            {
                                switch possibility 
                                {
                                case .symbol(let symbol):
                                    print("\(i).", self[symbol] ?? ecosystem[symbol])
                                default: 
                                    print("\(i). (unavailable)")
                                }
                            }
                            print("note: location is \(self[symbol] ?? ecosystem[symbol])")
                        }
                    }
                    else 
                    {
                        print("unknown", $0)
                    }
                    return .fallback($0)
                }
            } 
        }

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
        var dependencies:[Set<Module.Index>] = try graphs.map 
        {
            try self.dependencies($0.dependencies, given: ecosystem)
        }
        for (index, culture):(Int, Module.Index) in zip(dependencies.indices, cultures)
        {
            // remove self-dependencies 
            dependencies[index].remove(culture)
            // apply dependency updates
            self.dependencies.update(head: &self.modules[local: culture].heads.dependencies, 
                to: version, with: dependencies[index])
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
        -> Sources
    {
        let extant:Int = self.symbols.count
        
        var updated:Int = 0 
        var modules:[[Symbol.Index: Vertex.Frame]] = []
            modules.reserveCapacity(graphs.count)
        for (graph, scope):(Module.Graph, Symbol.Scope) in zip(graphs, scopes)
        {
            let frames:[Symbol.Index: Vertex.Frame] = 
                self.insert(symbols: graph, scope: scope, keys: &keys)
            modules.append(frames)
            updated += frames.count
        }
        
        print("(\(self.id)) updated \(updated) symbols (\(self.symbols.count - extant) are new)")
        return .init(modules: modules)
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
    
    private mutating 
    func update(declarations:[[Symbol.Index: Symbol.Declaration]], to version:Version)
    {
        for (symbol, declaration):(Symbol.Index, Symbol.Declaration) in declarations.joined() 
        {
            self.declarations.update(head: &self.symbols[local: symbol].heads.declaration, 
                to: version, with: declaration)
        }
    }
    private mutating 
    func update(relationships:[[Symbol.Index: Symbol.Relationships]], to version:Version)
    {
        for (symbol, relationships):(Symbol.Index, Symbol.Relationships) in relationships.joined()
        {
            self.relationships.update(head: &self.symbols[local: symbol].heads.relationships, 
                to: version, with: relationships)
        }
    }
    
    private 
    func dependencies(_ dependencies:[Module.Graph.Dependency], given ecosystem:Ecosystem) 
        throws -> Set<Module.Index>
    {
        var dependencies:[ID: [Module.ID]] = [ID: [Module.Graph.Dependency]]
            .init(grouping: dependencies, by: \.package)
            .mapValues 
        {
            $0.flatMap(\.modules)
        }
        // add implicit dependencies 
            dependencies[.swift, default: []].append(contentsOf: ecosystem.standardModules)
        if self.id != .swift 
        {
            dependencies[.core,  default: []].append(contentsOf: ecosystem.coreModules)
        }
        var modules:Set<Module.Index> = []
        for (id, namespaces):(ID, [Module.ID]) in dependencies 
        {
            guard let package:Self = self.id == id ? self : ecosystem[id]
            else 
            {
                throw Package.ResolutionError.dependency(id, of: self.id)
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
    private 
    func stdlib(given ecosystem:Ecosystem) -> Set<Module.Index>
    {
        guard let package:Self = self.id == .swift ? self : ecosystem[.swift] 
        else 
        {
            return []
        }
        return .init(package.modules.indices.values)
    }
    private 
    func bind<Modules>(_ modules:Modules, given ecosystem:Ecosystem, keys:Route.Keys) 
        throws -> [[Link.UniqueResolution: Extension]]
        where Modules:Sequence, Modules.Element == ([(String, Extension)], Module.Scope)
    {
        try modules.map 
        {
            // build a single-lens lexicon for the bindings. it should contain *all* our 
            // available namespaces, but only *one* lens.
            let lexicon:Lexicon = .init(keys: keys, namespaces: $0.1, lenses: [self.lens])
            var extensions:[Link.UniqueResolution: Extension] = [:]
            for (binding, article):(String, Extension) in $0.0
            {
                let expression:Link.Expression = try Link.Expression.init(relative: binding)
                let binding:Link.Resolution? = lexicon.resolve(visible: expression.reference)
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
         -> Lexicon.Lens
    {
        var lens:Lexicon.Lens = .init()
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
