extension SurfaceBuilder 
{
    fileprivate 
    struct Node 
    {
        let position:Branch.Position<Symbol> 
        var metadata:Symbol.Metadata
        var shape:Symbol.Shape<Tree.Position<Symbol>>?
    }
    fileprivate 
    struct Nodes:RandomAccessCollection 
    {
        private 
        var storage:[Node]
        private(set) 
        var indices:[Branch.Position<Symbol>: Symbols.Index]

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
            self.indices[node.position] = .init(offset: self.storage.endIndex)
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
        subscript(index:Symbols.Index) -> (Branch.Position<Symbol>, Symbol.Metadata) 
        {
            let node:Node = self.nodes[index.offset]
            return (node.position, node.metadata)
        }
    }
}
struct SurfaceBuilder 
{
    struct Context:Sendable 
    {
        let upstream:[Package.Index: Package._Pinned]
        let local:Package 

        subscript(global position:Tree.Position<Symbol>) -> Symbol 
        {
            if  let symbol:Symbol = self.local.tree[position] ?? 
                    self.upstream[position.package]?.package.tree[local: position]
            {
                return symbol
            }
            else 
            {
                fatalError("unreachable: SurfaceBuilder.Context does not contain requested package (index: \(position.package))")
            }
        }
    }

    private(set)
    var previous:Surface 
    private(set)
    var routes:Routes

    private(set)
    var articles:[(Branch.Position<Article>, Article.Metadata)], 
        foreign:[(Branch.Diacritic, Symbol.ForeignMetadata)], 
        modules:[Branch.Position<Module>]
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

        for (article, _cached):(Tree.Position<Article>?, Extension) in 
            zip(interface.citizenArticles, interface._cachedMarkdown)
        {
            if let article:Tree.Position<Article>
            {
                self.previous.articles.remove(article.contemporary)
                self.articles.append((article.contemporary, .init(_extension: _cached)))
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

        var external:[Tree.Position<Symbol>: [Symbol.Trait<Tree.Position<Symbol>>]] = [:]
        var traits:[Tree.Position<Symbol>: [Symbol.Trait<Tree.Position<Symbol>>]] = [:]
        var roles:[Tree.Position<Symbol>: [Symbol.Role<Tree.Position<Symbol>>]] = [:]
        for belief:Belief in beliefs 
        {
            switch (symbols.culture == belief.subject.contemporary.culture, belief.predicate)
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

        for position:Tree.Position<Symbol>? in symbols 
        {
            if let position:Tree.Position<Symbol>
            {
                assert(symbols.culture == position.contemporary.culture)

                self.previous.symbols.remove(position.contemporary)
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
        for (position, traits):(Tree.Position<Symbol>, [Symbol.Trait<Tree.Position<Symbol>>]) in 
            external
        {
            if  let subject:Symbol = context.local.tree[position], 
                let index:Symbols.Index = self.nodes.indices[position.contemporary]
            {
                let diacritic:Branch.Diacritic = .init(host: position.contemporary, 
                    culture: symbols.culture)

                self.nodes[index].metadata.accepted[symbols.culture] = 
                    self.createForeignSurface(for: subject, metadata: self.nodes[index].metadata, 
                        diacritic: diacritic,
                        traits: traits, 
                        context: context)
            }
            else if let pinned:Package._Pinned = context.upstream[position.package],
                    let metadata:Symbol.Metadata = pinned.metadata(local: position.contemporary)
            {
                let subject:Symbol = pinned.package.tree[local: position]
                let diacritic:Branch.Diacritic = .init(host: position.contemporary, 
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
    func createLocalSurface(for position:Tree.Position<Symbol>,
        traits:__owned [Symbol.Trait<Tree.Position<Symbol>>], 
        roles:__owned [Symbol.Role<Tree.Position<Symbol>>], 
        context:Context)
        -> Node 
    {
        let symbol:Symbol = context.local.tree[local: position] 

        var shape:Symbol.Shape<Tree.Position<Symbol>>? = nil 
        // partition relationships buffer 
        var superclass:Branch.Position<Symbol>? = nil 
        var residuals:[Symbol.Role<Branch.Position<Symbol>>] = []
        for role:Symbol.Role<Tree.Position<Symbol>> in roles
        {
            switch (shape, role) 
            {
            case  (nil,            .member(of: let type)): 
                shape =            .member(of:     type) 
            case (nil,        .requirement(of: let interface)): 
                shape =       .requirement(of:     interface) 
            
            case (let shape?,      .member(of: let type)):
                guard case         .member(of:     type) = shape 
                else 
                {
                    fatalError("unimplemented")
                    // throw PoliticalError.conflict(is: shape.role, 
                    //     and: .member(of: type))
                }
            case (let shape?, .requirement(of: let interface)): 
                guard case    .requirement(of:     interface) = shape 
                else 
                {
                    fatalError("unimplemented")
                    // throw PoliticalError.conflict(is: shape.role, 
                    //     and: .requirement(of: interface))
                }
                
            case (_,             .subclass(of: let type)): 
                switch superclass 
                {
                case nil, type.contemporary?:
                    superclass = type.contemporary
                case _?:
                    fatalError("unimplemented")
                    // throw PoliticalError.conflict(is: .subclass(of: superclass), 
                    //     and: .subclass(of: type))
                }
                
            default: 
                residuals.append(role.map(\.contemporary))
            }
        }
            
        let roles:Branch.SymbolRoles? = .init(residuals, 
            superclass: superclass, 
            shape: shape?.map(\.contemporary), 
            as: symbol.community)
        let traits:Tree.SymbolTraits = .init(traits, as: symbol.community)
        
        self.routes.natural.append(symbol.route, position: position.contemporary)
        if  let routes:SyntheticRoutes = .init(host: symbol, 
                diacritic: .init(natural: position.contemporary), 
                features: traits.features, 
                context: context)
        {
            self.routes.synthetic.append(routes)
        }
        
        return .init(position: position.contemporary, 
            metadata: .init(roles: roles, primary: traits.idealized()),
            shape: shape)
    }
    private mutating 
    func createForeignSurface(for subject:Symbol, metadata:Symbol.Metadata, 
        diacritic:Branch.Diacritic, 
        traits:__owned [Symbol.Trait<Tree.Position<Symbol>>], 
        context:Context)
        -> Branch.SymbolTraits
    {
        let traits:Tree.SymbolTraits = 
            .init(traits, as: subject.community)
            .subtracting(metadata.primary)

        if  let routes:SyntheticRoutes = .init(host: subject, diacritic: diacritic, 
                features: traits.features, 
                context: context)
        {
            self.routes.synthetic.append(routes)
        }
        return traits.idealized()
    }

    private mutating 
    func add(member:Branch.Position<Symbol>, to scope:Branch.Position<Symbol>)
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
            // is safe to compare contemporary offsets.
            if node.position.offset < symbols.startIndex
            {
                continue 
            }
            if let shape:Symbol.Shape<Tree.Position<Symbol>> = node.shape 
            {
                // already have a shape from a member or requirement belief
                symbols[contemporary: node.position].shape = shape
                continue 
            }

            let symbol:Symbol = symbols[_contemporary: node.position]
            guard   case nil = symbol.shape, 
                    let scope:Path = .init(symbol.path.prefix)
            else 
            {
                continue 
            }
            //  attempt to re-parent this symbol using lexical lookup. 
            //  this is a *very* heuristical process.
            if  let scope:Route.Key = stems[symbol.route.namespace, straight: scope]
            {
                let selection:_Selection<Tree.Position<Symbol>>? = routes.select(scope)
                {
                    (branch:_Version.Branch, composite:Branch.Composite) in 
                    composite.natural.map { $0.pluralized(branch) }
                }
                if case .one(let scope)? = selection 
                {
                    symbols[contemporary: node.position].shape = .member(of: scope)
                    self.add(member: node.position, to: scope.contemporary) 
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