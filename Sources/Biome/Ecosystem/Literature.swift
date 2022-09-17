import SymbolGraphs 
import DOM
import URI

extension DocumentationExtension:Equatable where Position:Equatable 
{
    static 
    func == (lhs:Self, rhs:Self) -> Bool 
    {
        lhs.extends == rhs.extends && 
        lhs.card == rhs.card && 
        lhs.body == rhs.body 
    }
}
struct DocumentationExtension<Position> 
{
    var extends:Position?
    var errors:[any Error]
    let card:DOM.Flattened<GlobalLink.Presentation>
    let body:DOM.Flattened<GlobalLink.Presentation>

    init()
    {
        self.extends = nil
        self.errors = []
        self.card = .init()
        self.body = .init()
    }
    init(inheriting extends:Position)
    {
        self.extends = extends 
        self.errors = []
        self.card = .init()
        self.body = .init()
    }
    init(compiling _extension:__owned Extension, extending extends:Position? = nil,
        resolver:Resolver,
        imports:Set<Branch.Position<Module>>, 
        scope:_Scope?, 
        stems:Route.Stems) 
    {
        let (card, body):(DOM.Flattened<String>, DOM.Flattened<String>) = 
            _extension.rendered()
        
        var errors:[any Error] = []

        func resolve(expression:String) 
            -> DOM.Substitution<GlobalLink.Presentation, String.UTF8View>
        {
            do 
            {
                return .key(try resolver.resolve(expression: expression, 
                    imports: imports, 
                    scope: scope, 
                    stems: stems))
            }
            catch let error 
            {
                errors.append(error)
                return .segment(expression.utf8)
            }
        }

        self.extends = extends 
        self.card = card.transform(resolve(expression:))
        self.body = body.transform(resolve(expression:))
        self.errors = errors
    }
}


struct Literature 
{
    private 
    struct Comment 
    {
        enum Node 
        {
            case inherits(Branch.Position<Symbol>)
            case extends(Branch.Position<Symbol>?, with:String)
        }

        let node:Node 
        let branch:_Version.Branch 

        init(_ node:Node, branch:_Version.Branch)
        {
            self.node = node 
            self.branch = branch
        }
    }
    private 
    struct Comments 
    {
        private 
        var uptree:[Branch.Position<Symbol>: Comment] = [:]
        private(set)
        var pruned:Int

        init() 
        {
            self.uptree = [:]
            self.pruned = 0
        }

        mutating 
        func update(with graph:SymbolGraph, interface:ModuleInterface)
        {
            for (position, vertex):(Tree.Position<Symbol>?, SymbolGraph.Vertex<Int>) in 
                zip(interface.citizenSymbols, graph.vertices)
            {
                guard let position:Tree.Position<Symbol> = position
                else 
                {
                    continue 
                }

                assert(position.contemporary.culture == interface.culture)
                
                switch 
                (
                    vertex.comment.string, 
                    vertex.comment.extends.flatMap { interface.symbols[$0]?.contemporary }
                )
                {
                case (nil, nil): 
                    continue 
                
                case (let comment?, nil):
                    self.uptree[position.contemporary] = .init(.extends(nil, with: comment), 
                        branch: position.branch)
                
                case (let comment?, let origin?):
                    if  origin.culture != interface.culture,
                        case .extends(_, with: comment)? = self.uptree[origin]?.node
                    {
                        // inherited a comment from a *different* module. 
                        // if it were from the same module, symbolgraphconvert 
                        // should have deleted it. 
                        self.uptree[position.contemporary] = .init(.inherits(origin), 
                            branch: position.branch)
                        pruned += 1
                    }
                    else 
                    {
                        self.uptree[position.contemporary] = .init(.extends(origin, with: comment), 
                            branch: position.branch)
                    }
                
                case (nil, let origin?):
                    self.uptree[position.contemporary] = .init(.inherits(origin), 
                        branch: position.branch)
                }
            }
        }

        func consolidated(culture:Package.Index) -> [Branch.Position<Symbol>: Comment]
        {
            var skipped:Int = 0,
                dropped:Int = 0
            defer 
            {
                if skipped != 0 
                {
                    print("shortened \(skipped) doccomment inheritance links")
                }
                if dropped != 0 
                {
                    print("pruned \(dropped) nil-terminating doccomment inheritance chains")
                }
            }
            return self.uptree.compactMapValues 
            {
                if case .inherits(var origin) = $0.node 
                {
                    // fast-forward until we either reach a package boundary, 
                    // or a local symbol that has documentation
                    var visited:Set<Branch.Position<Symbol>> = []
                    fastforwarding:
                    while origin.nationality == culture
                    {
                        if case _? = visited.update(with: origin)
                        {
                            fatalError("detected cycle in doccomment inheritance graph")
                        }
                        switch self.uptree[origin]?.node
                        {
                        case nil: 
                            dropped += 1
                            return nil 
                        case .extends(_, with: _)?: 
                            break fastforwarding
                        case .inherits(let next)?: 
                            origin = next 
                            skipped += 1
                        }
                    }
                    return .init(.inherits(origin), branch: $0.branch)
                }
                else 
                {
                    return $0
                }
            }
        }
    }
    private(set) 
    var articles:[(Branch.Position<Article>, DocumentationExtension<Never>)]
    private(set) 
    var symbols:[(Branch.Position<Symbol>, DocumentationExtension<Branch.Position<Symbol>>)]
    private(set) 
    var modules:[(Branch.Position<Module>, DocumentationExtension<Never>)]
    private(set) 
    var package:DocumentationExtension<Never>?

    init(compiling graphs:__owned [SymbolGraph], interfaces:__owned [ModuleInterface], 
        package local:Package.Index, 
        version:_Version, 
        context:__shared Packages, 
        stems:__shared Route.Stems)
    {
        self.articles = []
        self.symbols = []
        self.modules = []
        self.package = nil

        var comments:Comments = .init()
        for (graph, interface):(SymbolGraph, ModuleInterface) in zip(graphs, interfaces)
        {
            comments.update(with: graph, interface: interface)
        }
        if  comments.pruned != 0 
        {
            print("pruned \(comments.pruned) duplicate comments")
        }

        self.compile(graphs: _move graphs, interfaces: _move interfaces, 
            comments: (_move comments).consolidated(culture: local),
            package: .init(context[local], version: version), 
            context: context, 
            stems: stems)
    }
    private mutating 
    func compile(graphs:__owned [SymbolGraph], 
        interfaces:__owned [ModuleInterface], 
        comments:__owned [Branch.Position<Symbol>: Comment], 
        package local:Package._Pinned, 
        context:Packages,
        stems:Route.Stems)
    {
        var resolvers:[Branch.Position<Module>: Resolver] = .init(minimumCapacity: graphs.count)
        for (_, interface):(SymbolGraph, ModuleInterface) in zip(_move graphs, _move interfaces)
        {
            // use the interface-level pins and not the package-level pins, 
            // to reduce the size of the search context
            let resolver:Resolver = .init(local: local, pins: interface.pins,
                namespaces: interface.namespaces,
                context: context)

            for (position, _extension):(Tree.Position<Article>?, Extension) in 
                zip(interface.citizenArticles, interface._cachedMarkdown)
            {
                let imports:Set<Branch.Position<Module>> = 
                    interface.namespaces.import(_extension.metadata.imports)
                // TODO: handle merge behavior block directive 
                if let position:Tree.Position<Article> 
                {
                    self.articles.append((position.contemporary, .init(
                        compiling: _move _extension, 
                        resolver: resolver, 
                        imports: imports, 
                        scope: .init(interface.culture), 
                        stems: stems)))
                }
                else if let binding:String = _extension.binding, 
                        let binding:URI = try? .init(relative: binding),
                        let binding:_SymbolLink = try? .init(binding)
                {
                    let binding:_SymbolLink.Resolution? = local.resolve(binding.revealed.disambiguated(), 
                        scope: .init(interface.culture), 
                        stems: stems)
                    {
                        local.exists($0) && 
                        binding.disambiguator.matches($0, context: resolver.context)
                    }
                    switch binding
                    {
                    case nil: 
                        print("warning: documentation extension has no resolved binding, skipping")
                        continue 
                    
                    // case .package(_): 
                    //     self.package = .init(compiling: _move _extension, 
                    //         resolver: resolver, 
                    //         imports: imports, 
                    //         scope: nil, 
                    //         stems: stems)
                    
                    case .module(let module): 
                        self.modules.append((module, .init(compiling: _move _extension, 
                            resolver: resolver, 
                            imports: imports, 
                            scope: .init(module), 
                            stems: stems)))
                    
                    case .composite(let composite):
                        guard   let natural:Branch.Position<Symbol> = composite.natural 
                        else 
                        {
                            print("warning: documentation extensions for composite APIs are unsupported, skipping")
                            continue 
                        }
                        if case .extends? = comments[natural]?.node
                        {
                            print("warning: documentation extension would overwrite existing documentation, skipping")
                            continue 
                        }
                        guard   let position:Tree.Position<Symbol> = 
                                    natural.pluralized(bisecting: local.symbols)
                        else 
                        {
                            fatalError("unreachable")
                        }
                        let symbol:Symbol = local.package.tree[local: position]
                        self.symbols.append((natural, .init(compiling: _move _extension, 
                            resolver: resolver,
                            imports: imports, 
                            scope: .init(symbol), 
                            stems: stems)))
                    
                    case .composites(_):
                        print("warning: documentation extension has multiple possible bindings, skipping")
                        continue  
                    }
                }
            }

            resolvers[interface.culture] = resolver
        }
        self.compile(comments: _move comments, resolvers: _move resolvers, stems: stems)
    }
    private mutating 
    func compile(comments:__owned [Branch.Position<Symbol>: Comment],
        resolvers:__owned [Branch.Position<Module>: Resolver], 
        stems:Route.Stems)
    {
        for (position, comment):(Branch.Position<Symbol>, Comment) in comments 
        {
            guard let resolver:Resolver = resolvers[position.culture] 
            else 
            {
                fatalError("unreachable")
            }

            let documentation:DocumentationExtension<Branch.Position<Symbol>>
            switch comment.node 
            {
            case .inherits(let origin):
                documentation = .init(inheriting: origin)
            
            case .extends(let origin, with: let markdown):
                let _extension:Extension = .init(markdown: markdown)
                let symbol:Symbol = 
                    resolver.local.package.tree[local: position.pluralized(comment.branch)]
                documentation = .init(compiling: _extension, extending: origin, 
                    resolver: resolver,
                    imports: resolver.namespaces.import(_extension.metadata.imports), 
                    scope: .init(symbol), 
                    stems: stems)
            }
            self.symbols.append((position, documentation))
        }
    }
}
