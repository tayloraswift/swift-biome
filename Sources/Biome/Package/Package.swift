import SymbolGraphs
import Versions
import URI 

extension PackageIdentifier
{
    var title:String 
    {
        switch self.kind
        {
        case .swift, .core:         return "swift"
        case .community(let name):  return name 
        }
    }
}

public 
struct Package:Identifiable, Sendable
{
    /// A globally-unique index referencing a package. 
    public 
    struct Index:Hashable, Comparable, Sendable 
    {
        let opaque:UInt16
        
        public static 
        func < (lhs:Self, rhs:Self) -> Bool 
        {
            lhs.opaque < rhs.opaque
        }
        
        var offset:Int 
        {
            .init(self.opaque)
        }
        init(offset:Int)
        {
            self.opaque = .init(offset)
        }
    }
    
    @available(*, deprecated, renamed: "ID.Kind")
    public 
    typealias Kind = ID.Kind 
    
    struct Heads 
    {
        @History<DocumentationNode>.Branch.Optional
        var documentation:History<DocumentationNode>.Branch.Head?
        
        init() 
        {
            self._documentation = .init()
        }
    }
    
    public 
    let id:PackageIdentifier
    var index:Index 
    {
        self.versions.package
    }
    var brand:String?
    private(set)
    var heads:Heads
    var versions:Versions
    private(set) 
    var modules:CulturalBuffer<Module, Module.Index>, 
        symbols:CulturalBuffer<Symbol, Symbol.Index>,
        articles:CulturalBuffer<Article, Article.Index>
    private(set)
    var external:[Symbol.Diacritic: History<Symbol.Traits>.Branch.Head]
    // per-module buffers
    private(set)
    var dependencies:History<Set<Module.Index>>, // always populated 
        toplevels:History<Set<Symbol.Index>>, // always populated 
        guides:History<Set<Article.Index>> // *not* always populated
    // per-article buffers
    private(set)
    var excerpts:History<Article.Excerpt>
    // per-symbol buffers 
    private(set)
    var declarations:History<Declaration<Symbol.Index>>, // always populated 
        facts:History<Symbol.Predicates> // always populated
    // per-(external) host buffers 
    private(set)
    var opinions:History<Symbol.Traits>
    // shared buffer. 
    private(set) 
    var documentation:History<DocumentationNode>
    private(set)
    var groups:[Route.Key: Symbol.Group]
    
    var name:String 
    {
        self.id.string
    }
    var kind:ID.Kind 
    {
        self.id.kind
    }
    
    init(id:ID, index:Index)
    {
        self.id = id 
        switch id.kind 
        {
        case .swift, .core: 
            self.brand = "Swift"
        case .community(_):
            self.brand = nil
        }
        self.heads = .init()
        self.versions = .init(package: index)
        
        self.groups = .init()
        self.modules = .init(startIndex: 0)
        self.symbols = .init(startIndex: 0)
        self.articles = .init(startIndex: 0)
        self.external = [:]
        self.toplevels = .init()
        self.guides = .init()
        self.dependencies = .init()
        self.declarations = .init()
        
        self.facts = .init()
        self.opinions = .init()
        
        self.documentation = .init()
        self.excerpts = .init()
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
    subscript(local article:Article.Index) -> Article
    {
        _read 
        {
            yield self.articles[local: article]
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
    subscript(article:Article.Index) -> Article?
    {
        self.index == article.module.package ? self[local: article] : nil
    }
    
    var title:String 
    {
        if let brand:String = self.brand 
        {
            return "\(brand) Documentation"
        }
        else 
        {
            return self.name
        }
    }
    func title<S>(_ title:S) -> String where S:StringProtocol 
    {
        if let brand:String = self.brand 
        {
            return "\(title) - \(brand) Documentation"
        }
        else 
        {
            return .init(title)
        }
    }
    
    func pinned() -> Pinned 
    {
        .init(self, at: self.versions.latest)
    }
    func pinned(_ pins:Pins) -> Pinned 
    {
        .init(self, at: pins[self.index] ?? self.versions.latest)
    }
    
    func prefix(arrival:MaskedVersion?) -> [String]
    {
        switch (self.kind, arrival)
        {
        case    (.swift, nil), 
                (.core,  nil):
            return []
        case    (.swift, let version?), 
                (.core,  let version?):
            return [version.description]
        case    (.community(let name), let version?):
            return [name, version.description]
        case    (.community(let name), nil):
            return [name]
        }
    }
    
    func depth(of composite:Symbol.Composite, at version:Version, route:Route.Key)
        -> (host:Bool, base:Bool)
    {
        var explicit:(host:Bool, base:Bool) = (false, false)
        switch self.groups[route]
        {
        case nil: 
            assert(false)
        
        case .one((let occupant, _))?:
            assert(occupant == composite)
        
        case .many(let occupants)?:
            filtering:
            for (base, diacritics):(Symbol.Index, Symbol.Subgroup) in occupants
            {
                switch (base == composite.base, diacritics)
                {
                case (true, .one((let diacritic, _))):
                    assert(diacritic == composite.diacritic)
                
                case (false, .one((let diacritic, _))):
                    if self.contains(.init(base, diacritic), at: version)
                    {
                        explicit.base = true 
                    }
                    
                case (true, .many(let diacritics)):
                    for diacritic:Symbol.Diacritic in diacritics.keys 
                        where diacritic != composite.diacritic 
                    {
                        if self.contains(.init(base, diacritic), at: version)
                        {
                            explicit.base = true 
                            explicit.host = true 
                            break filtering
                        }
                    }
                
                case (false, .many(let diacritics)):
                    for diacritic:Symbol.Diacritic in diacritics.keys 
                    {
                        if self.contains(.init(base, diacritic), at: version)
                        {
                            explicit.base = true 
                            continue filtering
                        }
                    }
                }
            }
        }
        return explicit
    }
    
    func allVersions(of composite:Symbol.Composite) -> [Version]
    {
        self.versions.indices.filter { self.contains(composite, at: $0) }
    }
    func allVersions(of article:Article.Index) -> [Version]
    {
        self.versions.indices.filter { self.contains(article, at: $0) }
    } 
    func allVersions(of module:Module.Index) -> [Version]
    {
        self.versions.indices.filter { self.contains(module, at: $0) }
    } 
    func allVersions() -> [Version]
    {
        .init(self.versions.indices)
    } 
    
    //  each ecosystem entity has a type of versioned node that stores 
    //  evolutionary information. 
    // 
    //  - modules: self.dependencies 
    //  - articles: self.templates 
    //  - local symbols: self.facts 
    //  - external symbols: self.opinions 
    mutating 
    func updateVersion(_ version:PreciseVersion, dependencies:[Index: Version]) -> Package.Pins
    {
        self.versions.push(version, dependencies: dependencies)
    }

    // we don’t use this quite the same as `contains(_:at:)` for ``Symbol.Composite``, 
    // because we still allow accessing module pages outside their availability ranges. 
    // 
    // we mainly use this to limit the results in the version menu dropdown.
    // FIXME: the complexity of this becomes quadratic-ish if we test *every* 
    // package version with this method.
    func contains(_ module:Module.Index, at version:Version) -> Bool 
    {
        self.dependencies[self[local: module].heads.dependencies].contains(version)
    }
    func contains(_ article:Article.Index, at version:Version) -> Bool 
    {
        self.documentation[self[local: article].heads.documentation].contains(version)
    }
    func contains(_ symbol:Symbol.Index, at version:Version) -> Bool 
    {
        self.facts[self.symbols[local: symbol].heads.facts].contains(version)
    }
    // FIXME: the complexity of this becomes quadratic-ish if we test *every* 
    // package version with this method, which we do for the version menu dropdowns
    func contains(_ composite:Symbol.Composite, at version:Version) -> Bool 
    {
        guard let host:Symbol.Index = composite.host
        else 
        {
            // natural symbol 
            return self.contains(composite.base, at: version)
        }
        if let heads:Symbol.Heads = self[host]?.heads
        {
            // local host (primary or accepted culture)
            if  let predicates:Symbol.Predicates = self.facts[heads.facts].at(version), 
                let traits:Symbol.Traits = composite.culture == host.module ? 
                    predicates.primary : predicates.accepted[composite.culture]
            {
                return traits.features.contains(composite.base)
            }
            else 
            {
                return false 
            }
        }
        // external host
        else if let traits:Symbol.Traits = 
            self.opinions[self.external[composite.diacritic]].at(version)
        {
            return traits.features.contains(composite.base)
        }
        else 
        {
            return false 
        }
    }
    
    mutating 
    func pollinate(local symbol:Symbol.Index, from pin:Module.Pin)
    {
        self.symbols[local: symbol].pollen.insert(pin)
    }
    mutating 
    func move(module:Module.Index, to uri:URI) -> Pins
    {
        self.modules[local: module].redirect.module = (uri, self.versions.latest)
        return self.versions.pins(at: self.versions.latest)
    }
    mutating 
    func move(articles module:Module.Index, to uri:URI) -> Pins
    {
        self.modules[local: module].redirect.articles = (uri, self.versions.latest)
        return self.versions.pins(at: self.versions.latest)
    }
    
    func currentOpinion(_ diacritic:Symbol.Diacritic) -> Symbol.Traits?
    {
        self.external[diacritic].map { self.opinions[$0.index].value }
    }
}

extension Package 
{
    mutating 
    func pushBeliefs(_ beliefs:inout Beliefs, stems:Route.Stems)
    {
        self.inferShapes(&beliefs.facts, stems: stems)

        let current:Version = self.versions.latest
        for (index, facts):(Symbol.Index, Symbol.Facts) in beliefs.facts
        {
            self.facts.push(facts.predicates, version: current, 
                into: &self.symbols[local: index].heads.facts)
        }
        for (diacritic, traits):(Symbol.Diacritic, Symbol.Traits) in beliefs.opinions 
        {
            self.opinions.push(traits, version: current, 
                into: &self.external[diacritic])
        }
    }
    mutating 
    func pushDependencies(_ dependencies:Set<Module.Index>, culture:Module.Index)
    {
        self.dependencies.push(dependencies, version: self.versions.latest,
            into: &self.modules[local: culture].heads.dependencies)
    }
    mutating 
    func pushDeclarations(_ declarations:[(Symbol.Index, Declaration<Symbol.Index>)]) 
    {
        let current:Version = self.versions.latest
        for (index, declaration):(Symbol.Index, Declaration<Symbol.Index>) in declarations
        {
            self.declarations.push(declaration, version: current, 
                into: &self.symbols[local: index].heads.declaration)
        }
    }
    mutating 
    func pushDocumentation(_ compiled:[Ecosystem.Index: DocumentationNode])
    {
        let current:Version = self.versions.latest
        for (index, documentation):(Ecosystem.Index, DocumentationNode) in compiled 
        {
            switch index 
            {
            case .composite(let composite):
                guard case nil = composite.host 
                else 
                {
                    fatalError("unimplemented")
                }
                self.documentation.push(documentation, version: current, 
                    into: &self.symbols[local: composite.base].heads.documentation)
                
            case .article(let index): 
                self.documentation.push(documentation, version: current, 
                    into: &self.articles[local: index].heads.documentation)
                
            case .module(let index): 
                self.documentation.push(documentation, version: current, 
                    into: &self.modules[local: index].heads.documentation)
            case .package(self.index): 
                self.documentation.push(documentation, version: current, 
                    into: &self.heads.documentation)
            
            case .package(_): 
                fatalError("unreachable")
            }
        }
    }
    mutating 
    func pushExtensionMetadata(articles:[Article.Index: Extension], culture:Module.Index) 
    {
        let current:Version = self.versions.latest
        for (index, article):(Article.Index, Extension) in articles
        {
            let excerpt:Article.Excerpt = .init(title: article.headline.plainText,
                headline: article.headline.rendered(as: [UInt8].self),
                snippet: article.snippet)
            self.excerpts.push(excerpt, version: current, 
                into: &self.articles[local: index].heads.excerpt)
        }
        let guides:Set<Article.Index> = .init(articles.keys)
        if !guides.isEmpty 
        {
            self.guides.push(guides, version: current, 
                into: &self.modules[local: culture].heads.guides)
        }
    }
    mutating 
    func pushToplevel(filtering updates:Abstractor.Updates)
    {
        var toplevel:Set<Symbol.Index> = [] 
        for symbol:Symbol.Index? in updates 
        {
            if let symbol:Symbol.Index, self[local: symbol].path.prefix.isEmpty
            {
                // a symbol is toplevel if it has a single path component. this 
                // is not the same thing as having a `nil` shape.
                toplevel.insert(symbol)
            }
        }
        self.toplevels.push(toplevel, version: self.versions.latest, 
            into: &self.modules[local: updates.culture].heads.toplevel)
    }
}

extension Package 
{
    /// Registers the given modules.
    /// 
    /// >   Note: Module indices are *not* necessarily contiguous, or even monotonically increasing.
    mutating 
    func addModules(_ modules:some Sequence<Module.ID>) -> [Module.Index]
    {
        modules.map 
        { 
            self.modules.insert($0, culture: self.index, Module.init(id:index:))
        }
    }
    
    mutating 
    func addExtensions(from graph:SymbolGraph, 
        stems:inout Route.Stems, 
        culture:Module.Index) 
        -> (articles:[Article.Index: Extension], extensions:[String: Extension])
    {
        return ([:], [:])
        // var articles:[Article.Index: Extension] = [:]
        // var extensions:[String: Extension] = [:] 
        
        // let start:Article.Index = .init(culture, offset: self.articles.count)
        // for (name, source):(name:String, source:String) in graph.extensions
        // {
        //     let article:Extension = .init(markdown: source)
        //     if let binding:String = article.binding 
        //     {
        //         extensions[binding] = article 
        //         continue 
        //     }
        //     let path:Path 
        //     if let explicit:Path = article.metadata.path 
        //     {
        //         path = explicit 
        //     }
        //     else if !name.isEmpty 
        //     {
        //         // replace spaces in the article name with hyphens
        //         path = .init(last: .init(name.map { $0 == " " ? "-" : $0 }))
        //     }
        //     else 
        //     {
        //         print("warning: article with no filename must have an explicit @path(_:)")
        //         continue 
        //     }
        //     // article namespace is always its culture. 
        //     let route:Route.Key = .init(culture, 
        //               stems.register(components: path.prefix), 
        //         .init(stems.register(component:  path.last), 
        //         orientation: .straight))
        //     let index:Article.Index = 
        //         self.articles.insert(.init(route), culture: culture)
        //     {
        //         (id:Article.ID, _:Article.Index) in .init(id: id, path: path)
        //     }
        //     articles[index] = article
        // }
        // let end:Article.Index = .init(culture, offset: self.articles.count)
        // if start < end
        // {
        //     self.modules[local: culture].articles.append(start ..< end)
        // }
        // return (articles, extensions)
    }
    
    mutating 
    func addSymbols(from graph:SymbolGraph, 
        abstractor:inout Abstractor, 
        stems:inout Route.Stems,
        scope:Module.Scope) 
    {
        // for (namespace, vertices):(Module.ID, ArraySlice<SymbolGraph.Vertex<Int>>) in graph.colonies
        // {
        //     // will always succeed for the core subgraph
        //     guard let namespace:Module.Index = scope[namespace]
        //     else 
        //     {
        //         print("warning: ignored colonial symbolgraph '\(graph.id)@\(namespace)'")
        //         print("note: '\(namespace)' is not a known dependency of '\(graph.id)'")
        //         continue 
        //     }
            
        //     let start:Int = self.symbols.count
        //     for (offset, vertex):(Int, SymbolGraph.Vertex<Int>) in zip(vertices.indices, vertices)
        //     {
        //         if let index:Symbol.Index = abstractor[offset]
        //         {
        //             if index.module != scope.culture 
        //             {
        //                 print(
        //                     """
        //                     warning: symbol '\(vertex.path)' has already been registered in a \
        //                     different module (while loading symbolgraph of culture '\(graph.id)')
        //                     """)
        //             }
        //             // already registered this symbol
        //             continue 
        //         }
        //         let index:Symbol.Index = self.symbols.insert(graph.identifiers[offset], 
        //             culture: scope.culture)
        //         {
        //             (id:Symbol.ID, _:Symbol.Index) in 
        //             let route:Route.Key = .init(namespace, 
        //                       stems.register(components: vertex.path.prefix), 
        //                 .init(stems.register(component:  vertex.path.last), 
        //                 orientation: vertex.community.orientation))
        //             // if the symbol could inherit features, generate a stem 
        //             // for its children from its full path. this stem will only 
        //             // go to waste if a concretetype is completely uninhabited, 
        //             // which is very rare.
        //             let kind:Symbol.Kind 
        //             switch vertex.community
        //             {
        //             case .associatedtype: 
        //                 kind = .associatedtype 
        //             case .concretetype(let concrete): 
        //                 kind = .concretetype(concrete, path: vertex.path.prefix.isEmpty ? 
        //                     route.leaf.stem : stems.register(components: vertex.path))
        //             case .callable(let callable): 
        //                 kind = .callable(callable)
        //             case .global(let global): 
        //                 kind = .global(global)
        //             case .protocol: 
        //                 kind = .protocol 
        //             case .typealias: 
        //                 kind = .typealias
        //             }
        //             return .init(id: id, path: vertex.path, kind: kind, route: route)
        //         }
                
        //         abstractor[offset] = index
        //     }
        //     let end:Int = self.symbols.count 
        //     if start < end
        //     {
        //         self.modules[local: scope.culture].symbols.append(Symbol.ColonialRange.init(
        //             namespace: namespace, offsets: start ..< end))
        //     }
        // }
    }
    mutating 
    func inferShapes(_ facts:inout [Symbol.Index: Symbol.Facts], stems:Route.Stems)
    {
        for index:Dictionary<Symbol.Index, Symbol.Facts>.Index in facts.indices
        {
            let local:Symbol.Index = facts.keys[index]

            if  let shape:Symbol.Shape = facts.values[index].shape 
            {
                self.symbols[local: local].shape = shape
                continue 
            }

            let symbol:Symbol = self.symbols[_local: local]
            guard   case nil = symbol.shape,
                    let scope:Path = .init(symbol.path.prefix)
            else 
            {
                continue 
            }
            // attempt to re-parent this symbol using lexical lookup
            if  let scope:Route.Key = stems[symbol.route.namespace, scope], 
                case .one((let scope, _))? = self.groups[scope], 
                let scope:Symbol.Index = scope.natural
            {
                self.symbols[local: local].shape = .member(of: scope)
                if scope.culture == local.culture 
                {
                    facts[scope]?.predicates.primary
                        .members.insert(local)
                }
                else 
                {
                    facts[scope]?.predicates.accepted[local.culture, default: .init()]
                        .members.insert(local)
                }
            }
            else 
            {
                print("warning: orphaned symbol \(symbol)")
                continue 
            }
        }
    }
    mutating 
    func addNaturalRoutes(_ trees:[Route.NaturalTree])
    {
        for tree:Route.NaturalTree in trees 
        {
            let route:Route = tree.route 
            self.groups[route.key].insert(route.target)
        }
    }
    mutating 
    func addSyntheticRoutes(_ trees:[Route.SyntheticTree])
    {
        for tree:Route.SyntheticTree in trees 
        {
            for route:Route in tree 
            {
                self.groups[route.key].insert(route.target)
            }
        }
    }
}
