struct _Version:Hashable, Sendable 
{
    struct Branch:Hashable, Sendable 
    {
        let index:Int 
    }
    struct Revision:Hashable, Strideable, Sendable
    {
        let index:Int 

        static 
        func < (lhs:Self, rhs:Self) -> Bool
        {
            lhs.index < rhs.index
        }
        func advanced(by stride:Int.Stride) -> Self 
        {
            .init(index: self.index.advanced(by: stride))
        }
        func distance(to other:Self) -> Int.Stride
        {
            self.index.distance(to: other.index)
        }
    }

    var branch:Branch
    var revision:Revision
}
struct Trunk:Sendable 
{
    let ring:Branch.Ring 
    let modules:CulturalBuffer<Module, Module.Index>, 
        symbols:CulturalBuffer<Symbol, Symbol.Index>,
        articles:CulturalBuffer<Article, Article.Index>

    func index(of module:Module.ID) -> Module.Index? 
    {
        if  let module:Module.Index = self.modules.indices[module], 
                module.offset < self.ring.modules 
        {
            return module 
        }
        else 
        {
            return nil
        }
    }
}
struct Branch:Sendable 
{
    struct Date:Sendable 
    {
        var year:UInt16 
        var month:UInt16 
        var day:UInt16 
        var hour:UInt8
    }
    struct Ring:Sendable 
    {
        let revision:Int 
        let modules:Module.Index.Offset
        let symbols:Symbol.Index.Offset
        let articles:Article.Index.Offset
    }
    struct Revision:Sendable 
    {
        let date:Date 
        let ring:Ring
        let pins:[Package.Index: _Version]
        var consumers:[Package.Index: Set<_Version>]
    }

    private 
    var revisions:[Revision]

    let fork:_Version?
    let name:PreciseVersion
    var heads:Package.Heads

    var updatedModules:[Module.Index: Module.Heads], 
        updatedSymbols:[Symbol.Index: Symbol.Heads], 
        updatedArticles:[Article.Index: Article.Heads]
    var newModules:CulturalBuffer<Module, Module.Index>, 
        newSymbols:CulturalBuffer<Symbol, Symbol.Index>,
        newArticles:CulturalBuffer<Article, Article.Index>
    
    subscript(prefix:PartialRangeUpTo<_Version.Revision>) -> Trunk 
    {
        .init(ring: self.revisions[prefix.upperBound.index].ring, 
            modules: self.newModules, 
            symbols: self.newSymbols, 
            articles: self.newArticles)
    }
}

extension Branch 
{
    mutating 
    func addModules(_ modules:some Sequence<Module.ID>, trunks:[Trunk], culture:Package.Index) 
        -> [Module.Index]
    {
        modules.map 
        { 
            for trunk:Trunk in trunks 
            {
                if let existing:Module.Index = trunk.index(of: $0)
                {
                    return existing 
                }
            }
            return self.newModules.insert($0, culture: culture, Module.init(id:index:))
        }
    }
    mutating 
    func addSymbols(from graph:SymbolGraph, trunks:[Trunk], 
        namespaces:Namespaces,
        abstractor:inout Abstractor, 
        stems:inout Route.Stems) 
    {
        for (namespace, vertices):(Module.ID, ArraySlice<SymbolGraph.Vertex<Int>>) in graph.colonies
        {
            // will always succeed for the core subgraph
            guard let namespace:Module.Index = namespaces[namespace]
            else 
            {
                print("warning: ignored colonial symbolgraph '\(graph.id)@\(namespace)'")
                print("note: '\(namespace)' is not a known dependency of '\(graph.id)'")
                continue 
            }
            
            let start:Symbol.Index.Offset = self.newSymbols.endIndex
            for (offset, vertex):(Int, SymbolGraph.Vertex<Int>) in zip(vertices.indices, vertices)
            {
                if let index:Symbol.Index = abstractor[offset]
                {
                    if index.module != namespaces.culture 
                    {
                        print(
                            """
                            warning: symbol '\(vertex.path)' has already been registered in a \
                            different module (while loading symbolgraph of culture '\(graph.id)')
                            """)
                    }
                    // already registered this symbol
                    continue 
                }
                let index:Symbol.Index = self.newSymbols.insert(graph.identifiers[offset], 
                    culture: namespaces.culture)
                {
                    (id:Symbol.ID, _:Symbol.Index) in 
                    let route:Route.Key = .init(namespace, 
                              stems.register(components: vertex.path.prefix), 
                        .init(stems.register(component:  vertex.path.last), 
                        orientation: vertex.community.orientation))
                    // if the symbol could inherit features, generate a stem 
                    // for its children from its full path. this stem will only 
                    // go to waste if a concretetype is completely uninhabited, 
                    // which is very rare.
                    let kind:Symbol.Kind 
                    switch vertex.community
                    {
                    case .associatedtype: 
                        kind = .associatedtype 
                    case .concretetype(let concrete): 
                        kind = .concretetype(concrete, path: vertex.path.prefix.isEmpty ? 
                            route.leaf.stem : stems.register(components: vertex.path))
                    case .callable(let callable): 
                        kind = .callable(callable)
                    case .global(let global): 
                        kind = .global(global)
                    case .protocol: 
                        kind = .protocol 
                    case .typealias: 
                        kind = .typealias
                    }
                    return .init(id: id, path: vertex.path, kind: kind, route: route)
                }
                
                abstractor[offset] = index
            }
            let end:Symbol.Index.Offset = self.newSymbols.endIndex 
            if start < end
            {
                let colony:Module.Colony = .init(namespace: namespace, range: start ..< end)
                switch namespaces.origin 
                {
                case .shared(let culture):
                    self.updatedModules[culture, default: .init()].symbols.append(colony)
                case .founded(let culture):
                    self.newModules[local: culture].heads.symbols.append(colony)
                }
            }
        }
    }
    mutating 
    func addExtensions(from graph:SymbolGraph, 
        origin:CulturalBuffer<Module, Module.Index>.Origin, 
        stems:inout Route.Stems) 
        -> (articles:[Article.Index: Extension], extensions:[String: Extension])
    {
        var articles:[Article.Index: Extension] = [:]
        var extensions:[String: Extension] = [:] 
        
        let start:Article.Index.Offset = self.newArticles.endIndex
        for (name, source):(name:String, source:String) in graph.extensions
        {
            let article:Extension = .init(markdown: source)
            if let binding:String = article.binding 
            {
                extensions[binding] = article 
                continue 
            }
            let path:Path 
            if let explicit:Path = article.metadata.path 
            {
                path = explicit 
            }
            else if !name.isEmpty 
            {
                // replace spaces in the article name with hyphens
                path = .init(last: .init(name.map { $0 == " " ? "-" : $0 }))
            }
            else 
            {
                print("warning: article with no filename must have an explicit @path(_:)")
                continue 
            }
            // article namespace is always its culture. 
            let route:Route.Key = .init(origin.index, 
                      stems.register(components: path.prefix), 
                .init(stems.register(component:  path.last), 
                orientation: .straight))
            let index:Article.Index = 
                self.newArticles.insert(.init(route), culture: origin.index)
            {
                (id:Article.ID, _:Article.Index) in .init(id: id, path: path)
            }
            articles[index] = article
        }
        let end:Article.Index.Offset = self.newArticles.endIndex
        if start < end
        {
            switch origin 
            {
            case .shared(let culture):
                self.updatedModules[culture, default: .init()].articles.append(start ..< end)
            case .founded(let culture):
                self.newModules[local: culture].heads.articles.append(start ..< end)
            }
        }
        return (articles, extensions)
    }
}
extension Package 
{
    var _versions:_Versions
    {
        _read 
        {
            fatalError("unimplemented")
        }
        _modify
        {
            fatalError("unimplemented")
        }
    }

    struct _Versions 
    {
        let culture:Package.Index
        private 
        var branches:[Branch]

        subscript(branch:_Version.Branch) -> Branch 
        {
            _read 
            {
                yield  self.branches[branch.index]
            }
            _modify
            {
                yield &self.branches[branch.index]
            }
        }
    }
}
extension Package._Versions 
{
    /// Registers the given modules.
    /// 
    /// >   Note: Module indices are *not* necessarily contiguous, or even monotonically increasing.
    mutating 
    func addModules(_ modules:some Sequence<Module.ID>, to branch:_Version.Branch) -> [Module.Index]
    {
        var trunks:[Trunk] = []
        var current:Branch = self[branch]
        while let fork:_Version = current.fork 
        {
            current = self[fork.branch]
            trunks.append(current[..<fork.revision])
        }
        return self[branch].addModules(modules, trunks: trunks, culture: self.culture)
    }
}
