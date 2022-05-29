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
    
    struct Heads 
    {
        @Keyframe<Documentation>.Head
        var documentation:Keyframe<Documentation>.Buffer.Index?
        
        init() 
        {
            self._documentation = .init()
        }
    }
    
    public 
    let id:ID
    let index:Index
    
    private
    var heads:Heads
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
        documentation:Keyframe<Documentation>.Buffer
        
    private
    var groups:Symbol.Groups
    var lens:Lexicon.Lens 
    {
        .init(groups: self.groups.table, learn: self.articles.indices)
    }
    
    var name:String 
    {
        self.id.string
    }
    
    init(id:ID, index:Index)
    {
        self.id = id 
        self.index = index
        
        self.heads = .init()
        
        // self.tag = "2.0.0"
        self.groups = .init()
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
    
    func scope(ecosystem:Ecosystem, culture:Module.Index, at version:Version) 
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
        let lenses:[[Symbol.ID: Symbol.Index]] = scope.packages().map 
        {
            ecosystem[$0].symbols.indices
        }
        return .init(namespaces: scope, lenses: lenses)
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
        case linked(Link.Target)
        case attached(String)
        case external(Extension)
    }
    
    var symbol:[Link.Target: Comment]
} */
extension Package 
{
    mutating 
    func update(with graphs:[Module.Graph], 
        ecosystem:Ecosystem, 
        pins:[Index: Version], 
        keys:inout Route.Keys) 
        throws -> [Index: [Symbol.Index: [Symbol.Trait]]]
    {
        let version:Version = pins[self.index] ?? .latest
        // create modules, if they do not exist already.
        // note: module indices are *not* necessarily contiguous, 
        // or even monotonically increasing
        let cultures:[Module.Index] = self.addModules(graphs)
        
        let dependencies:[Set<Module.Index>] = 
            try ecosystem.dependencies(self, graphs, cultures: cultures)
        
        self.update(dependencies: _move(dependencies), cultures: cultures, to: version)
        
        var scopes:[Symbol.Scope] = cultures.map 
        { 
            self.scope(ecosystem: ecosystem, culture: $0, at: version) 
        }
        
        let sources:Sources = self.addSources(graphs, scopes: scopes, keys: &keys)
        let extras:Extras = self.addExtras(graphs, cultures: cultures, keys: &keys)
        
        // add the newly-registered symbols to each module scope 
        for scope:Int in scopes.indices
        {
            scopes[scope].lenses.append(self.symbols.indices)
        }
        
        // resolve symbol declarations, extract doccomments 
        let comments:[[Symbol.Index: String]] = sources.comments()
        let declarations:[[Symbol.Index: Symbol.Declaration]] = 
            try sources.declarations(scopes: scopes)
        
        let _ = _move(sources)
        
        // resolve edge statements 
        let (speeches, sponsorships):([[Symbol.Statement]], [Symbol.Sponsorship]) = 
            try ecosystem.statements(self, graphs, scopes: scopes)
        
        // compute relationships
        let ideologies:[Module.Index: Module.Beliefs] = try self.beliefs(_move(speeches), 
            about: declarations.map(\.keys),
            cultures: cultures)
        
        // defer the merge until the end to reduce algorithmic complexity
        self.groups.merge(keys.groups(ideologies) { self[$0] ?? ecosystem[$0] })
        
        print("(\(self.id)) found \(self.lens.groups.count) addressable endpoints")
        
        // merge opinions into a single dictionary
        let opinions:[Index: [Symbol.Index: [Symbol.Trait]]] = 
            ideologies.values.reduce(into: [:])
        {
            $0.merge($1.opinions) { $0.merging($1, uniquingKeysWith: + ) }
        }
        
        // apply versioned updates
        self.update(declarations:  _move(declarations),                   to: version)
        self.update(relationships: _move(ideologies).values.map(\.facts), to: version)
        
        let documentation:[Link.Target: Documentation] = self.documentation(
                ecosystem: ecosystem,
                comments: _move(comments), 
                extras: _move(extras), 
                scopes: scopes.map(\.namespaces), 
                keys: keys)
        // TODO: deduplicate docs! 
        self.update(documentation: documentation, to: version)
        
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
    func update(dependencies:[Set<Module.Index>], cultures:[Module.Index], to version:Version) 
    {
        for (index, dependencies):(Module.Index, Set<Module.Index>) in zip(cultures, dependencies)
        {
            self.dependencies.update(head: &self.modules[local: index].heads.dependencies, 
                to: version, with: dependencies)
        }
    }
    private mutating 
    func update(declarations:[[Symbol.Index: Symbol.Declaration]], to version:Version)
    {
        for (index, declaration):(Symbol.Index, Symbol.Declaration) in declarations.joined() 
        {
            self.declarations.update(head: &self.symbols[local: index].heads.declaration, 
                to: version, with: declaration)
        }
    }
    private mutating 
    func update(relationships:[[Symbol.Index: Symbol.Relationships]], to version:Version)
    {
        for (index, relationships):(Symbol.Index, Symbol.Relationships) in relationships.joined()
        {
            self.relationships.update(head: &self.symbols[local: index].heads.relationships, 
                to: version, with: relationships)
        }
    }
    private mutating 
    func update(documentation:[Link.Target: Documentation], to version:Version)
    {
        for (target, documentation):(Link.Target, Documentation) in documentation 
        {
            switch target 
            {
            case .article(let index): 
                self.documentation.update(head: &self.articles[local: index].heads.documentation, 
                    to: version, with: documentation)
            
            case .feature(_, _): 
                fatalError("unimplemented")
            
            case .symbol(let index): 
                self.documentation.update(head: &self.symbols[local: index].heads.documentation, 
                    to: version, with: documentation)
            case .module(let index): 
                self.documentation.update(head: &self.modules[local: index].heads.documentation, 
                    to: version, with: documentation)
            case .package(self.index): 
                self.documentation.update(head: &self.heads.documentation, 
                    to: version, with: documentation)
            
            case .package(_): 
                fatalError("unreachable")
            }
        }
    }
}

extension Package 
{
    private mutating 
    func addModules(_ graphs:[Module.Graph]) -> [Module.Index]
    {
        graphs.map 
        { 
            self.modules.insert($0.core.namespace, culture: self.index, Module.init(id:index:))
        }
    }
}
// sources 
extension Package 
{
    struct Sources 
    {
        fileprivate 
        let modules:[[Symbol.Index: Vertex.Frame]]
    }
    
    mutating 
    func addSources(_ graphs:[Module.Graph], scopes:[Symbol.Scope], keys:inout Route.Keys) 
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
}
extension Package.Sources 
{
    func comments() -> [[Symbol.Index: String]]
    {
        self.modules.map 
        { 
            $0.compactMapValues 
            {
                $0.comment.isEmpty ? nil : $0.comment
            } 
        }
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
}

// peripherals 
extension Package 
{
    struct Extras 
    {
        fileprivate 
        let articles:[[Article.Index: Extension]], 
            extensions:[[String: Extension]]
    }
    
    mutating 
    func addExtras(_ graphs:[Module.Graph], cultures:[Module.Index], keys:inout Route.Keys) 
        -> Extras
    {
        var extensions:[[String: Extension]] = []
            extensions.reserveCapacity(cultures.count)
        var articles:[[Article.Index: Extension]] = []
            articles.reserveCapacity(cultures.count)
        for (culture, graph):(Module.Index, Module.Graph) in zip(cultures, graphs)
        {
            var unregistered:[String: Extension] = [:] 
            var registered:[Article.Index: Extension] = [:]
            for article:Extension in graph.articles
            {
                if let binding:String = article.binding 
                {
                    unregistered[binding] = article 
                    continue 
                }
                // article namespace is always its culture
                let path:[String] = article.metadata.path
                let nest:[String] = .init(path.dropLast()),
                    name:String = path[path.endIndex - 1]
                let id:Route = .init(culture, 
                          keys.register(components: nest), 
                    .init(keys.register(component:  name), 
                    orientation: .straight))
                let index:Article.Index = self.articles.insert(id, culture: culture)
                {
                    (route:Route, _:Article.Index) in 
                    .init(nest: nest, name: name, route: route)
                }
                registered[index] = article
            }
            extensions.append(unregistered)
            articles.append(registered)
        }
        return .init(articles: articles, extensions: extensions)
    }
}
extension Package.Extras
{
    func assigned(lexica:[Lexicon], _ dereference:(Symbol.Index) throws -> Symbol) 
        rethrows -> [[Link.Target: Extension]]
    {
        var modules:[[Link.Target: Extension]] = [] 
            modules.reserveCapacity(lexica.count)
        for (lexicon, (articles, extensions)):(Lexicon, ([Article.Index: Extension], [String: Extension])) in 
            zip(lexica, zip(self.articles, self.extensions))
        {
            var bindings:[Link.Target: Extension] = [:]
                bindings.reserveCapacity(articles.count + extensions.count)
            for (index, article):(Article.Index, Extension) in articles 
            {
                bindings[.article(index)] = article
            }
            for (binding, article):(String, Extension) in extensions
            {
                guard let link:Link.Expression = try? Link.Expression.init(relative: binding)
                else 
                {
                    print("warning: ignored article with invalid binding '\(binding)'")
                    continue 
                }
                switch try lexicon.resolve(visible: link.reference, dereference)
                {
                case .many(_)?, nil: 
                    fatalError("unimplemented")
                case .one(let unique)?:
                    // TODO: emit warning for colliding extensions
                    bindings[unique] = article 
                }
            }
            modules.append(bindings)
        }
        return modules
    }
}
