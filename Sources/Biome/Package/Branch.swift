import PackageResolution

enum _Dependency:Sendable 
{
    case available(_Version)
    case unavailable(Branch.ID, String)
}
enum _DependencyError:Error 
{
    case package                                (unavailable:Package.ID)
    case pin                                    (unavailable:Package.ID)
    case version           (unavailable:(Branch.ID, String), Package.ID)
    case module (unavailable:Module.ID, (Branch.ID, String), Package.ID)
}
struct _Version:Hashable, Sendable 
{
    struct Branch:Hashable, Sendable 
    {
        let index:Int 

        init(_ index:Int)
        {
            self.index = index
        }
    }
    struct Revision:Hashable, Strideable, Sendable
    {
        let index:Int 

        init(_ index:Int)
        {
            self.index = index
        }

        static 
        func < (lhs:Self, rhs:Self) -> Bool
        {
            lhs.index < rhs.index
        }
        func advanced(by stride:Int.Stride) -> Self 
        {
            .init(self.index.advanced(by: stride))
        }
        func distance(to other:Self) -> Int.Stride
        {
            self.index.distance(to: other.index)
        }
    }

    var branch:Branch
    var revision:Revision

    init(_ branch:Branch, _ revision:Revision)
    {
        self.branch = branch 
        self.revision = revision 
    }
}
struct Trunk:Sendable 
{
    let branch:_Version.Branch
    let modules:Branch.Buffer<Module>.SubSequence, 
        symbols:Branch.Buffer<Symbol>.SubSequence,
        articles:Branch.Buffer<Article>.SubSequence
    
    func position<Element>(_ index:Element.Index) -> Tree.Position<Element> 
        where Element:BranchElement 
    {
        .init(index, branch: self.branch)
    }
}
public 
struct Branch:Identifiable, Sendable 
{
    public 
    enum ID:Hashable, Sendable 
    {
        case master 
        case custom(String)
        case semantic(SemanticVersion)

        init(_ requirement:PackageResolution.Requirement)
        {
            switch requirement 
            {
            case .version(let version): 
                self = .semantic(version)
            case .branch("master"), .branch("main"): 
                self = .master
            case .branch(let name): 
                self = .custom(name)
            }
        }
    }
    // struct Date:Hashable, Sendable 
    // {
    //     var year:UInt16 
    //     var month:UInt16 
    //     var day:UInt16 
    //     var hour:UInt8
    // }
    struct Ring:Sendable 
    {
        let revision:Int 
        let modules:Module.Offset
        let symbols:Symbol.Offset
        let articles:Article.Offset
    }
    struct Revision:Sendable 
    {
        let ring:Ring
        let hash:String 
        let pins:[Package.Index: _Version]
        var consumers:[Package.Index: Set<_Version>]
    }

    public 
    let id:ID
    let index:_Version.Branch

    let fork:_Version?
    var heads:Package.Heads
    private 
    var revisions:[Revision]

    private(set)
    var newModules:Buffer<Module>, 
        newSymbols:Buffer<Symbol>,
        newArticles:Buffer<Article>
    private(set)
    var updatedModules:[Module.Index: Module.Heads], 
        updatedSymbols:[Symbol.Index: Symbol.Heads], 
        updatedArticles:[Article.Index: Article.Heads]
    
    var startIndex:_Version.Revision 
    {
        .init(self.revisions.startIndex)
    }
    var endIndex:_Version.Revision 
    {
        .init(self.revisions.endIndex)
    }
    var indices:Range<_Version.Revision> 
    {
        self.startIndex ..< self.endIndex
    }
    subscript(revision:_Version.Revision) -> Revision
    {
        _read 
        {
            yield  self.revisions[revision.index]
        }
        _modify
        {
            yield &self.revisions[revision.index]
        }
    }

    init(id:ID, index:_Version.Branch, fork:(version:_Version, ring:Ring)?)
    {
        self.id = id 
        self.index = index 

        self.fork = fork?.version
        self.heads = .init() 
        self.revisions = []
        
        self.newModules = .init(startIndex: fork?.ring.modules ?? 0)
        self.newSymbols = .init(startIndex: fork?.ring.symbols ?? 0)
        self.newArticles = .init(startIndex: fork?.ring.articles ?? 0)

        self.updatedModules = [:]
        self.updatedSymbols = [:]
        self.updatedArticles = [:]
    }
    
    subscript(prefix:PartialRangeUpTo<_Version.Revision>) -> Trunk 
    {
        let ring:Ring = self.revisions[prefix.upperBound.index].ring
        return .init(branch: self.index, 
            modules: self.newModules[..<ring.modules], 
            symbols: self.newSymbols[..<ring.symbols], 
            articles: self.newArticles[..<ring.articles])
    }

    // FIXME: this could be made a lot more efficient
    func find(_ hash:String) -> _Version.Revision?
    {
        for revision:_Version.Revision in self.indices
        {
            if self[revision].hash == hash 
            {
                return revision 
            }
        }
        return nil 
    }

    func position<Element>(_ index:Element.Index) -> Tree.Position<Element> 
        where Element:BranchElement 
    {
        .init(index, branch: self.index)
    }
}

extension Sequence<Trunk> 
{
    func find(module:Module.ID) -> Tree.Position<Module>? 
    {
        for trunk:Trunk in self 
        {
            if let module:Module.Index = trunk.modules.opaque(of: module)
            {
                return .init(module, branch: trunk.branch)
            }
        }
        return nil
    }
}
extension Branch 
{
    mutating 
    func addModule(_ id:Module.ID, culture:Package.Index, trunks:[Trunk]) -> Tree.Position<Module>
    {
        if let existing:Tree.Position<Module> = trunks.find(module: id)
        {
            return existing 
        }
        else 
        {
            return self.position(self.newModules.insert(id, culture: culture, 
                Module.init(id:index:)))
        }
    }
    // mutating 
    // func addSymbols(from graph:SymbolGraph, namespaces:Namespaces,
    //     abstractor:inout Abstractor, 
    //     stems:inout Route.Stems) 
    // {
    //     for (namespace, vertices):(Module.ID, ArraySlice<SymbolGraph.Vertex<Int>>) in graph.colonies
    //     {
    //         // will always succeed for the core subgraph
    //         guard let namespace:Module.Index = namespaces[namespace]
    //         else 
    //         {
    //             print("warning: ignored colonial symbolgraph '\(graph.id)@\(namespace)'")
    //             print("note: '\(namespace)' is not a known dependency of '\(graph.id)'")
    //             continue 
    //         }
            
    //         let start:Symbol.Offset = self.newSymbols.endIndex
    //         for (offset, vertex):(Int, SymbolGraph.Vertex<Int>) in zip(vertices.indices, vertices)
    //         {
    //             if let index:Symbol.Index = abstractor[offset]
    //             {
    //                 if index.module != namespaces.culture 
    //                 {
    //                     print(
    //                         """
    //                         warning: symbol '\(vertex.path)' has already been registered in a \
    //                         different module (while loading symbolgraph of culture '\(graph.id)')
    //                         """)
    //                 }
    //                 // already registered this symbol
    //                 continue 
    //             }
    //             let index:Symbol.Index = self.newSymbols.insert(graph.identifiers[offset], 
    //                 culture: namespaces.culture)
    //             {
    //                 (id:Symbol.ID, _:Symbol.Index) in 
    //                 let route:Route.Key = .init(namespace, 
    //                           stems.register(components: vertex.path.prefix), 
    //                     .init(stems.register(component:  vertex.path.last), 
    //                     orientation: vertex.community.orientation))
    //                 // if the symbol could inherit features, generate a stem 
    //                 // for its children from its full path. this stem will only 
    //                 // go to waste if a concretetype is completely uninhabited, 
    //                 // which is very rare.
    //                 let kind:Symbol.Kind 
    //                 switch vertex.community
    //                 {
    //                 case .associatedtype: 
    //                     kind = .associatedtype 
    //                 case .concretetype(let concrete): 
    //                     kind = .concretetype(concrete, path: vertex.path.prefix.isEmpty ? 
    //                         route.leaf.stem : stems.register(components: vertex.path))
    //                 case .callable(let callable): 
    //                     kind = .callable(callable)
    //                 case .global(let global): 
    //                     kind = .global(global)
    //                 case .protocol: 
    //                     kind = .protocol 
    //                 case .typealias: 
    //                     kind = .typealias
    //                 }
    //                 return .init(id: id, path: vertex.path, kind: kind, route: route)
    //             }
                
    //             abstractor[offset] = index
    //         }
    //         let end:Symbol.Offset = self.newSymbols.endIndex 
    //         if start < end
    //         {
    //             let colony:Module.Colony = .init(namespace: namespace, range: start ..< end)
    //             switch namespaces.origin 
    //             {
    //             case .shared(let culture):
    //                 self.updatedModules[culture, default: .init()].symbols.append(colony)
    //             case .founded(let culture):
    //                 self.newModules[local: culture].heads.symbols.append(colony)
    //             }
    //         }
    //     }
    // }
    // mutating 
    // func addExtensions(from graph:SymbolGraph, 
    //     origin:CulturalBuffer<Module>.Origin, 
    //     stems:inout Route.Stems) 
    //     -> (articles:[Article.Index: Extension], extensions:[String: Extension])
    // {
    //     var articles:[Article.Index: Extension] = [:]
    //     var extensions:[String: Extension] = [:] 
        
    //     let start:Article.Offset = self.newArticles.endIndex
    //     for (name, source):(name:String, source:String) in graph.extensions
    //     {
    //         let article:Extension = .init(markdown: source)
    //         if let binding:String = article.binding 
    //         {
    //             extensions[binding] = article 
    //             continue 
    //         }
    //         let path:Path 
    //         if let explicit:Path = article.metadata.path 
    //         {
    //             path = explicit 
    //         }
    //         else if !name.isEmpty 
    //         {
    //             // replace spaces in the article name with hyphens
    //             path = .init(last: .init(name.map { $0 == " " ? "-" : $0 }))
    //         }
    //         else 
    //         {
    //             print("warning: article with no filename must have an explicit @path(_:)")
    //             continue 
    //         }
    //         // article namespace is always its culture. 
    //         let route:Route.Key = .init(origin.index, 
    //                   stems.register(components: path.prefix), 
    //             .init(stems.register(component:  path.last), 
    //             orientation: .straight))
    //         let index:Article.Index = 
    //             self.newArticles.insert(.init(route), culture: origin.index)
    //         {
    //             (id:Article.ID, _:Article.Index) in .init(id: id, path: path)
    //         }
    //         articles[index] = article
    //     }
    //     let end:Article.Offset = self.newArticles.endIndex
    //     if start < end
    //     {
    //         switch origin 
    //         {
    //         case .shared(let culture):
    //             self.updatedModules[culture, default: .init()].articles.append(start ..< end)
    //         case .founded(let culture):
    //             self.newModules[local: culture].heads.articles.append(start ..< end)
    //         }
    //     }
    //     return (articles, extensions)
    // }
}
