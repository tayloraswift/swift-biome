import SymbolGraphs
import SymbolSource

extension SurfaceBuilder 
{
    fileprivate 
    struct Node 
    {
        var metadata:Symbol.Metadata
        let element:Atom<Symbol> 
        var scope:Symbol.Scope<Atom<Symbol>.Position>?
    }
    fileprivate 
    struct Nodes:RandomAccessCollection 
    {
        private 
        var storage:[Node]
        private(set) 
        var indices:[Atom<Symbol>: Symbols.Index]

        init()
        {
            self.storage = []
            self.indices = [:]
        }

        var symbols:Symbols 
        {
            .init(self.storage)
        }

        var startIndex:Symbols.Index 
        {
            .init(offset: self.storage.startIndex)
        }
        var endIndex:Symbols.Index 
        {
            .init(offset: self.storage.endIndex)
        }
        subscript(index:Symbols.Index) -> Node 
        {
            _read 
            {
                yield  self.storage[index.offset]
            }
            _modify
            {
                yield &self.storage[index.offset]
            }
        }

        mutating 
        func append(_ node:Node)
        {
            self.indices[node.element] = .init(offset: self.storage.endIndex)
            self.storage.append(node)
        }
    }
    struct Symbols:RandomAccessCollection
    {
        struct Index:Strideable 
        {
            let offset:Int 

            @inlinable public
            func advanced(by stride:Int) -> Self 
            {
                .init(offset: self.offset.advanced(by: stride))
            }
            @inlinable public
            func distance(to other:Self) -> Int
            {
                self.offset.distance(to: other.offset)
            }
        }

        fileprivate 
        let nodes:[Node]

        fileprivate 
        init(_ nodes:[Node])
        {
            self.nodes = nodes
        }

        var startIndex:Symbols.Index 
        {
            .init(offset: self.nodes.startIndex)
        }
        var endIndex:Symbols.Index 
        {
            .init(offset: self.nodes.endIndex)
        }
        subscript(index:Symbols.Index) -> (Atom<Symbol>, Symbol.Metadata) 
        {
            let node:Node = self.nodes[index.offset]
            return (node.element, node.metadata)
        }
    }
}
struct SurfaceBuilder 
{
    struct Context:Sendable 
    {
        let upstream:[Packages.Index: Package.Pinned]
        let local:Package 

        subscript(global position:Atom<Symbol>.Position) -> Symbol 
        {
            if  let symbol:Symbol = self.local.tree[position] ?? 
                    self.upstream[position.nationality]?.package.tree[local: position]
            {
                return symbol
            }
            else 
            {
                fatalError("unreachable: SurfaceBuilder.Context does not contain requested package (index: \(position.nationality))")
            }
        }
    }

    private(set)
    var previous:Surface 
    private(set)
    var routes:Routes

    private(set)
    var articles:[(Atom<Article>, Article.Metadata)], 
        foreign:[(Diacritic, Symbol.ForeignMetadata)], 
        modules:[Atom<Module>]
    private 
    var nodes:Nodes

    var symbols:Symbols 
    {
        self.nodes.symbols
    }
    
    init(previous:Surface)
    {
        self.previous = previous
        self.routes = .init() 

        self.articles = []
        self.foreign = []
        self.modules = []

        self.nodes = .init()
    }

    mutating 
    func update(with edges:[SymbolGraph.Edge<Int>], interface:ModuleInterface, context:Context) 
    {
        self.previous.modules.remove(interface.culture)
        self.modules.append(interface.culture)

        for (article, _cached):(Atom<Article>.Position?, Extension) in 
            zip(interface.citizenArticles, interface._cachedMarkdown)
        {
            if let article:Atom<Article>.Position
            {
                self.previous.articles.remove(article.atom)
                self.articles.append((article.atom, .init(_extension: _cached)))
            }
        }
        
        let (beliefs, errors):([Belief], [ModuleInterface.LookupError]) = 
            interface.symbols.translate(edges: edges, context: context)
        
        if !errors.isEmpty 
        {
            print("warning: dropped \(errors.count) edges")
        }

        assert(interface.nationality == context.local.nationality)
        
        self.insert(_move beliefs, symbols: interface.citizenSymbols, context: context)
    }

    private mutating 
    func insert(_ beliefs:__owned [Belief], symbols:ModuleInterface.Citizens<Symbol>, 
        context:Context) 
    {

        var external:[Atom<Symbol>.Position: [Symbol.Trait<Atom<Symbol>.Position>]] = [:]
        var traits:[Atom<Symbol>.Position: [Symbol.Trait<Atom<Symbol>.Position>]] = [:]
        var roles:[Atom<Symbol>.Position: [Symbol.Role<Atom<Symbol>.Position>]] = [:]
        for belief:Belief in beliefs 
        {
            switch (symbols.culture == belief.subject.culture, belief.predicate)
            {
            case (false,  .is(_)):
                fatalError("unimplemented")
            case (false, .has(let trait)):
                external[belief.subject, default: []].append(trait)
            case (true,  .has(let trait)):
                traits[belief.subject, default: []].append(trait)
            case (true,   .is(let role)):
                roles[belief.subject, default: []].append(role)
            }
        }

        for position:Atom<Symbol>.Position? in symbols 
        {
            if let position:Atom<Symbol>.Position
            {
                assert(symbols.culture == position.culture)

                self.previous.symbols.remove(position.atom)
                self.nodes.append(self.createLocalSurface(for: position, 
                    traits: traits.removeValue(forKey: position) ?? [], 
                    roles: roles.removeValue(forKey: position) ?? [], 
                    context: context))
            }
        }
        guard traits.isEmpty, roles.isEmpty 
        else 
        {
            fatalError("unimplemented")
        }
        for (position, traits):(Atom<Symbol>.Position, [Symbol.Trait<Atom<Symbol>.Position>]) in 
            external
        {
            if  let subject:Symbol = context.local.tree[position], 
                let index:Symbols.Index = self.nodes.indices[position.atom]
            {
                let diacritic:Diacritic = .init(host: position.atom, 
                    culture: symbols.culture)

                self.nodes[index].metadata.accepted[symbols.culture] = 
                    self.createForeignSurface(for: subject, metadata: self.nodes[index].metadata, 
                        diacritic: diacritic,
                        traits: traits, 
                        context: context)
            }
            else if let pinned:Package.Pinned = context.upstream[position.nationality],
                    let metadata:Symbol.Metadata = pinned.metadata(local: position.atom)
            {
                let subject:Symbol = pinned.package.tree[local: position]
                let diacritic:Diacritic = .init(host: position.atom, 
                    culture: symbols.culture)
                
                let metadata:Symbol.ForeignMetadata = .init(traits: 
                    self.createForeignSurface(for: subject, metadata: metadata, 
                        diacritic: diacritic,
                        traits: traits, 
                        context: context))
                
                self.previous.foreign.remove(diacritic)
                self.foreign.append((diacritic, metadata))
            }
            else 
            {
                fatalError("unreachable: host not visible!")
            }
        }
    }

    private mutating 
    func createLocalSurface(for position:Atom<Symbol>.Position,
        traits:__owned [Symbol.Trait<Atom<Symbol>.Position>], 
        roles:__owned [Symbol.Role<Atom<Symbol>.Position>], 
        context:Context)
        -> Node 
    {
        let symbol:Symbol = context.local.tree[local: position] 

        var scope:Symbol.Scope<Atom<Symbol>.Position>? = nil
        // partition relationships buffer 
        var superclass:Atom<Symbol>? = nil 
        var residuals:[Symbol.Role<Atom<Symbol>>] = []
        for role:Symbol.Role<Atom<Symbol>.Position> in roles
        {
            switch (scope, role) 
            {
            case  (nil,            .member(of: let type)): 
                scope =            .member(of:     type) 
            case (nil,        .requirement(of: let interface)): 
                scope =       .requirement(of:     interface) 
            
            case (let scope?,      .member(of: let type)):
                guard case         .member(of:     type) = scope 
                else 
                {
                    fatalError("unimplemented")
                }
            case (let scope?, .requirement(of: let interface)): 
                guard case    .requirement(of:     interface) = scope 
                else 
                {
                    fatalError("unimplemented")
                }
                
            case (_,             .subclass(of: let type)): 
                switch superclass
                {
                case nil, type.atom?:
                    superclass = type.atom
                case _?:
                    fatalError("unimplemented")
                }
                
            default: 
                residuals.append(role.map(\.atom))
            }
        }
            
        let roles:Branch.SymbolRoles? = .init(residuals,
            superclass: superclass, 
            scope: scope?.map(\.atom), 
            as: symbol.shape)
        let traits:Tree.SymbolTraits = .init(traits, as: symbol.shape)
        
        self.routes.atomic.append(symbol.route, element: position.atom)
        if  let routes:CompoundRoutes = .init(host: symbol, 
                diacritic: .init(atomic: position.atom), 
                features: traits.features, 
                context: context)
        {
            self.routes.compound.append(routes)
        }
        
        return .init(metadata: .init(roles: roles, primary: traits.idealized()),
            element: position.atom, 
            scope: scope)
    }
    private mutating 
    func createForeignSurface(for subject:Symbol, metadata:Symbol.Metadata, diacritic:Diacritic, 
        traits:__owned [Symbol.Trait<Atom<Symbol>.Position>], 
        context:Context)
        -> Branch.SymbolTraits
    {
        let traits:Tree.SymbolTraits = 
            .init(traits, as: subject.shape)
            .subtracting(metadata.primary)

        if  let routes:CompoundRoutes = .init(host: subject, diacritic: diacritic, 
                features: traits.features, 
                context: context)
        {
            self.routes.compound.append(routes)
        }
        return traits.idealized()
    }

    private mutating 
    func add(member:Atom<Symbol>, to scope:Atom<Symbol>)
    {
        guard let index:Symbols.Index = self.nodes.indices[scope]
        else 
        {
            return
        }
        if member.culture == scope.culture
        {
            self.nodes[index].metadata.primary.members.insert(member)
        }
        else 
        {
            self.nodes[index].metadata.accepted[member.culture, default: .init()]
                .members.insert(member)
        }
    }
}

extension SurfaceBuilder 
{
    mutating 
    func inferScopes(for branch:inout Branch, fasces:Fasces, stems:Route.Stems)
    {
        self.inferScopes(for: &branch.symbols, 
            routes: fasces.routes(layering: branch.routes, branch: branch.index), 
            stems: stems)
    }
    private mutating 
    func inferScopes(for symbols:inout Branch.Buffer<Symbol>, 
        routes:Fasces.AugmentedRoutingView, 
        stems:Route.Stems)
    {
        for node:Node in self.nodes
        {
            // we know that every key in ``Surface.symbols`` is part of the current 
            // package, and that they are all part of the current timeline, so it 
            // is safe to compare atomic offsets.
            if node.element.offset < symbols.startIndex
            {
                continue 
            }
            if let scope:Symbol.Scope<Atom<Symbol>.Position> = node.scope 
            {
                // already have a scope from a member or requirement belief
                symbols[contemporary: node.element].scope = scope
                continue 
            }

            let symbol:Symbol = symbols[_contemporary: node.element]
            guard   case nil = symbol.scope, 
                    let scope:Path = .init(symbol.path.prefix)
            else 
            {
                continue 
            }
            //  attempt to re-parent this symbol using lexical lookup. 
            //  this is a *very* heuristical process.
            if  let scope:Route = stems[symbol.route.namespace, straight: scope]
            {
                let selection:Selection<Atom<Symbol>.Position>? = routes.select(scope)
                {
                    (branch:Version.Branch, composite:Composite) in 
                    composite.atom.map { $0.positioned(branch) }
                }
                if case .one(let scope)? = selection 
                {
                    symbols[contemporary: node.element].scope = .member(of: scope)
                    self.add(member: node.element, to: scope.atom) 
                    continue 
                }
            }
            
            print("warning: orphaned symbol \(symbol)")
        }
    }
}

extension SurfaceBuilder 
{
    func surface() -> Surface 
    {
        .init(articles: .init(self.articles.lazy.map(\.0)), 
            symbols: .init(self.nodes.indices.keys), 
            modules: .init(self.modules), 
            foreign: .init(self.foreign.lazy.map(\.0)))
    }
}