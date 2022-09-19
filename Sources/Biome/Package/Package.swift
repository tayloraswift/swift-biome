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
    
    public 
    let id:PackageIdentifier
    var brand:String?
    private(set) 
    var modules:CulturalBuffer<Module>, 
        symbols:CulturalBuffer<Symbol>,
        articles:CulturalBuffer<Article>
    
    var name:String 
    {
        self.id.string
    }
    var kind:ID.Kind 
    {
        self.id.kind
    }

    private(set)
    var metadata:Metadata, 
        data:Data 
    var tree:Tree

    @available(*, deprecated, renamed: "tree")
    var versions:Tree
    {
        self.tree
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
        
        self.modules = .init(startIndex: 0)
        self.symbols = .init(startIndex: 0)
        self.articles = .init(startIndex: 0)
        
        self.metadata = .init()
        self.data = .init()
        self.tree = .init(nationality: index)
    }

    var nationality:Index 
    {
        self.tree.nationality
    }
    @available(*, deprecated, renamed: "nationality")
    var index:Index 
    {
        self.nationality
    }

    subscript(local module:Module.Index) -> Module 
    {
        _read 
        {
            yield self.modules[contemporary: module]
        }
    }
    subscript(local symbol:Symbol.Index) -> Symbol
    {
        _read 
        {
            yield self.symbols[contemporary: symbol]
        }
    } 
    subscript(local article:Article.Index) -> Article
    {
        _read 
        {
            yield self.articles[contemporary: article]
        }
    } 
    
    subscript(module:Module.Index) -> Module?
    {
        self.nationality ==        module.package ? self[local: module] : nil
    }
    subscript(symbol:Symbol.Index) -> Symbol?
    {
        self.nationality == symbol.module.package ? self[local: symbol] : nil
    }
    subscript(article:Article.Index) -> Article?
    {
        self.nationality == article.module.package ? self[local: article] : nil
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

    // func pinned() -> Pinned 
    // {
    //     .init(self, at: self.versions.latest)
    // }
    // func pinned(_ pins:Pins) -> Pinned 
    // {
    //     .init(self, at: pins[self.index] ?? self.versions.latest)
    // }
    
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
    
    // func depth(of composite:Branch.Composite, at version:Version, route:Route.Key)
    //     -> (host:Bool, base:Bool)
    // {
    //     var explicit:(host:Bool, base:Bool) = (false, false)
    //     switch self.groups[route]
    //     {
    //     case nil: 
    //         assert(false)
        
    //     case .one((let occupant, _))?:
    //         assert(occupant == composite)
        
    //     case .many(let occupants)?:
    //         filtering:
    //         for (base, diacritics):(Symbol.Index, Branch.Substack) in occupants
    //         {
    //             switch (base == composite.base, diacritics)
    //             {
    //             case (true, .one((let diacritic, _))):
    //                 assert(diacritic == composite.diacritic)
                
    //             case (false, .one((let diacritic, _))):
    //                 if self.contains(.init(base, diacritic), at: version)
    //                 {
    //                     explicit.base = true 
    //                 }
                    
    //             case (true, .many(let diacritics)):
    //                 for diacritic:Branch.Diacritic in diacritics.keys 
    //                     where diacritic != composite.diacritic 
    //                 {
    //                     if self.contains(.init(base, diacritic), at: version)
    //                     {
    //                         explicit.base = true 
    //                         explicit.host = true 
    //                         break filtering
    //                     }
    //                 }
                
    //             case (false, .many(let diacritics)):
    //                 for diacritic:Branch.Diacritic in diacritics.keys 
    //                 {
    //                     if self.contains(.init(base, diacritic), at: version)
    //                     {
    //                         explicit.base = true 
    //                         continue filtering
    //                     }
    //                 }
    //             }
    //         }
    //     }
    //     return explicit
    // }
    
    func allVersions(of composite:Branch.Composite) -> [Version]
    {
        [] //self.versions.indices.filter { self.contains(composite, at: $0) }
    }
    func allVersions(of article:Article.Index) -> [Version]
    {
        [] //self.versions.indices.filter { self.contains(article, at: $0) }
    } 
    func allVersions(of module:Module.Index) -> [Version]
    {
        [] //self.versions.indices.filter { self.contains(module, at: $0) }
    } 
    func allVersions() -> [Version]
    {
        [] //.init(self.versions.indices)
    } 
    
    //  each ecosystem entity has a type of versioned node that stores 
    //  evolutionary information. 
    // 
    //  - modules: self.dependencies 
    //  - articles: self.templates 
    //  - local symbols: self.facts 
    //  - external symbols: self.opinions 
    // mutating 
    // func updateVersion(_ version:PreciseVersion, dependencies:[Index: Version]) -> Package.Pins
    // {
    //     self.versions.push(version, dependencies: dependencies)
    // }

    // we don’t use this quite the same as `contains(_:at:)` for ``Branch.Composite``, 
    // because we still allow accessing module pages outside their availability ranges. 
    // 
    // we mainly use this to limit the results in the version menu dropdown.
    // FIXME: the complexity of this becomes quadratic-ish if we test *every* 
    // package version with this method.
    func contains(_ module:Module.Index, at version:Version) -> Bool 
    {
        fatalError("obsoleted")
        // self.dependencies[self[local: module].heads.dependencies].contains(version)
    }
    func contains(_ article:Article.Index, at version:Version) -> Bool 
    {
        fatalError("obsoleted")
        // self.documentation[self[local: article].heads.documentation].contains(version)
    }
    func contains(_ symbol:Symbol.Index, at version:Version) -> Bool 
    {
        fatalError("obsoleted")
        // self.facts[self.symbols[local: symbol].heads.facts].contains(version)
    }
    // FIXME: the complexity of this becomes quadratic-ish if we test *every* 
    // package version with this method, which we do for the version menu dropdowns
    func contains(_ composite:Branch.Composite, at version:Version) -> Bool 
    {
        fatalError("obsoleted")
    }
    
    mutating 
    func pollinate(local symbol:Symbol.Index, from pin:Module.Pin)
    {
        self.symbols[local: symbol].pollen.insert(pin)
    }
    mutating 
    func move(module:Module.Index, to uri:URI) -> Pins
    {
        fatalError("unimplemented")
        // self.modules[local: module].redirect.module = (uri, self.versions.latest)
        // return self.versions.pins(at: self.versions.latest)
    }
    mutating 
    func move(articles module:Module.Index, to uri:URI) -> Pins
    {
        fatalError("unimplemented")
        // self.modules[local: module].redirect.articles = (uri, self.versions.latest)
        // return self.versions.pins(at: self.versions.latest)
    }
    
    func currentOpinion(_ diacritic:Branch.Diacritic) -> Symbol.Traits<Symbol.Index>?
    {
        fatalError("unimplemented")
        // self.external[diacritic].map { self.opinions[$0.index].value }
    }
}

extension Package 
{
    mutating 
    func updateMetadata(to version:Version, 
        interfaces:[ModuleInterface], 
        builder:SurfaceBuilder, 
        fasces:Fasces)
    {
        self.metadata.update(&self.tree[version.branch], to: version.revision, 
            interfaces: interfaces, 
            builder: builder, 
            fasces: fasces)
    }
    mutating 
    func updateData(to version:Version, graph:SymbolGraph, 
        interface:ModuleInterface, 
        fasces:Fasces)
    {
        self.data.updateDeclarations(&self.tree[version.branch], to: version.revision, 
            interface: interface, 
            graph: graph, 
            trunk: fasces.symbols)
        

        var topLevelSymbols:Set<Branch.Position<Symbol>> = [] 
        for position:PluralPosition<Symbol>? in interface.citizenSymbols
        {
            if  let position:PluralPosition<Symbol>, 
                self.tree[local: position].path.prefix.isEmpty
            {
                // a symbol is toplevel if it has a single path component. this 
                // is not the same thing as having a `nil` shape.
                topLevelSymbols.insert(position.contemporary)
            }
        }
        self.data.topLevelSymbols.update(&self.tree[version.branch].modules, 
            position: interface.culture, 
            with: _move topLevelSymbols, 
            revision: version.revision, 
            field: (\.topLevelSymbols, \.topLevelSymbols),
            trunk: fasces.modules)
        

        let topLevelArticles:Set<Branch.Position<Article>> = 
            .init(interface.citizenArticles.lazy.compactMap { $0?.contemporary })
        self.data.topLevelArticles.update(&self.tree[version.branch].modules, 
            position: interface.culture, 
            with: _move topLevelArticles, 
            revision: version.revision, 
            field: (\.topLevelArticles, \.topLevelArticles),
            trunk: fasces.modules)
    }
    mutating 
    func updateDocumentation(to version:Version, literature:__owned Literature, fasces:Fasces)
    {
        for (position, documentation):(Branch.Position<Module>, DocumentationExtension<Never>)
            in literature.modules 
        {
            self.data.standaloneDocumentation.update(&self.tree[version.branch].modules, 
                position: position, 
                with: documentation, 
                revision: version.revision, 
                field: (\.documentation, \.documentation),
                trunk: fasces.modules)
        }
        for (position, documentation):(Branch.Position<Article>, DocumentationExtension<Never>)
            in literature.articles 
        {
            self.data.standaloneDocumentation.update(&self.tree[version.branch].articles, 
                position: position, 
                with: documentation, 
                revision: version.revision, 
                field: (\.documentation, \.documentation),
                trunk: fasces.articles)
        }
        for (position, documentation):(Branch.Position<Symbol>, DocumentationExtension<Branch.Position<Symbol>>)
            in literature.symbols 
        {
            self.data.symbolDocumentation.update(&self.tree[version.branch].symbols, 
                position: position, 
                with: documentation, 
                revision: version.revision, 
                field: (\.documentation, \.documentation),
                trunk: fasces.symbols)
        }
    }
}