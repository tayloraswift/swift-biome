import SymbolGraphs 
import DOM
import URI

struct DocumentationExtension<Position> 
{
    var extends:Position
    var errors:[any Error]
    let card:DOM.Flattened<_SymbolLink.Presentation>
    let body:DOM.Flattened<_SymbolLink.Presentation>

    init(compiling _extension:__owned Extension, extending extends:Position? = nil,
        resolver:Resolver,
        imports:Set<Branch.Position<Module>>, 
        scope:_Scope?, 
        stems:Route.Stems) 
    {
        let (summary, body):(DOM.Flattened<String>, DOM.Flattened<String>) = 
            _extension.rendered()

        // summary.transform 
        // {
        //     (string:String) -> DOM.Substitution<_SymbolLink.Presentation, [UInt8]> in 
        // }
        fatalError("unimplemented")
    }
}


struct Literature 
{
    private 
    struct Comments 
    {
        enum Node 
        {
            case inherits(Branch.Position<Symbol>)
            case extends(Branch.Position<Symbol>?, with:String)
        }

        private 
        var uptree:[Branch.Position<Symbol>: Node] = [:]
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
                guard let position:Branch.Position<Symbol> = position?.contemporary
                else 
                {
                    continue 
                }
                
                switch 
                (
                    vertex.comment.string, 
                    vertex.comment.extends.flatMap { interface.symbols[$0]?.contemporary }
                )
                {
                case (nil, nil): 
                    continue 
                
                case (let comment?, nil):
                    self.uptree[position] = .extends(nil, with: comment)
                
                case (let comment?, let origin?):
                    if  origin.culture != interface.culture,
                        case .extends(_, with: comment)? = self.uptree[origin]
                    {
                        // inherited a comment from a *different* module. 
                        // if it were from the same module, symbolgraphconvert 
                        // should have deleted it. 
                        self.uptree[position] = .inherits(origin)
                        pruned += 1
                    }
                    else 
                    {
                        self.uptree[position] = .extends(origin, with: comment)
                    }
                
                case (nil, let origin?):
                    self.uptree[position] = .inherits(origin)
                }
            }
        }

        func consolidated(culture:Package.Index) -> [Branch.Position<Symbol>: Node]
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
                if case .inherits(var origin) = $0 
                {
                    // fast-forward until we either reach a package boundary, 
                    // or a local symbol that has documentation
                    var visited:Set<Branch.Position<Symbol>> = []
                    fastforwarding:
                    while origin.package == culture
                    {
                        if  case _? = visited.update(with: origin)
                        {
                            fatalError("detected cycle in doccomment inheritance graph")
                        }
                        switch self.uptree[origin] 
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
                    return .inherits(origin)
                }
                else 
                {
                    return $0
                }
            }
        }
    }
    private(set) 
    var articles:[(Branch.Position<Article>, DocumentationExtension<Void>)]
    private(set) 
    var symbols:[(Branch.Position<Symbol>, DocumentationExtension<Symbol.Index>)]
    private(set) 
    var modules:[(Branch.Position<Module>, DocumentationExtension<Void>)]
    private(set) 
    var package:DocumentationExtension<Void>?

    init(compiling graphs:__owned [SymbolGraph], 
        interfaces:__owned [ModuleInterface], 
        package local:Package.Index, 
        version:_Version, 
        context:__shared Packages, 
        stems:__shared Route.Stems)
    {
        self.articles = []
        self.symbols = []
        self.modules = []
        self.package = nil

        let local:Package._Pinned = .init(context[local], version: version)

        var comments:Comments = .init()
        for (graph, interface):(SymbolGraph, ModuleInterface) in zip(graphs, interfaces)
        {
            comments.update(with: graph, interface: interface)
        }
        if  comments.pruned != 0 
        {
            print("pruned \(comments.pruned) duplicate comments")
        }

        let nodes:[Branch.Position<Symbol>: Comments.Node] = 
            (_move comments).consolidated(culture: local.package.index)

        for (_, interface):(SymbolGraph, ModuleInterface) in zip(_move graphs, interfaces)
        {
            let upstream:[Package._Pinned] = interface.pins.map 
            {
                .init(context[$0.key], version: $0.value)
            }
            let resolver:Resolver = .init(local: local, upstream: upstream, 
                namespaces: interface.namespaces)

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
                    switch local.resolve(binding.revealed.disambiguated(), 
                        scope: .init(interface.culture), 
                        stems: stems)
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
                        if case .extends? = nodes[natural] 
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
        }
        //return comments 
        fatalError("unimplemented")
    }
}

struct Resolver 
{
    private 
    struct Lenses:RandomAccessCollection
    {
        let local:Package._Pinned
        let upstream:[Package._Pinned]

        var startIndex:Int 
        {
            -1 
        }
        var endIndex:Int
        {
            self.upstream.endIndex
        }
        subscript(index:Int) -> Package._Pinned 
        {
            _read 
            {
                yield index < 0 ? self.local : self.upstream[index]
            }
        }

        init(local:Package._Pinned, upstream:[Package._Pinned])
        {
            self.local = local
            self.upstream = upstream 
        }

        func select(_ key:Route.Key, imports:Set<Branch.Position<Module>>)
            -> _Selection<Branch.Composite>?
        {
            var selection:_Selection<Branch.Composite>? = nil 
            for lens:Package._Pinned in self
            {
                lens.routes.select(key)
                {
                    if  imports.contains($0.culture), lens.exists($0) 
                    {
                        selection.append($0)
                    }
                } as ()
            }
            return selection
        }
    }

    private 
    enum Scheme 
    {
        case symbol
        case doc
    }
    private 
    enum Hierarchy 
    {
        // '//swift-foo/foomodule/footype.foomember(_:)'
        case authority 
        // '/foomodule/footype.foomember(_:)'
        case absolute 
        // 'footype.foomember(_:)'
        case opaque
    }

    private 
    let lenses:Lenses 
    private 
    let namespaces:Namespaces

    init(local:Package._Pinned, upstream:[Package._Pinned], namespaces:Namespaces)
    {
        self.lenses = .init(local: local, upstream: upstream)
        self.namespaces = namespaces
    }

    func resolve(_ link:String, 
        imports:Set<Branch.Position<Module>>, 
        scope:_Scope?, 
        stems:Route.Stems) throws -> _SymbolLink.Presentation
    {
        let schemeless:Substring 
        let scheme:Scheme 
        if  let colon:String.Index = link.firstIndex(of: ":")
        {
            if link[..<colon] == "doc" 
            {
                scheme = .doc 
            }
            else 
            {
                throw _SymbolLink.ResolutionError.init(link, problem: .scheme)
            }
            schemeless = link[link.index(after: colon)...]
        }
        else 
        {
            scheme = .symbol
            schemeless = link[...]
        }
        var slashes:Int = 0
        for index:String.Index in schemeless.indices 
        {
            if  slashes <  2, schemeless[index] == "/" 
            {
                slashes += 1
                continue 
            }
            
            let hierarchy:Hierarchy
            switch slashes 
            {
            case 0: hierarchy = .opaque
            case 1: hierarchy = .absolute
            case _: hierarchy = .authority
            }
            do 
            {
                let uri:URI = try .init(relative: schemeless[index...])
                let link:_SymbolLink = try .init(uri)
                let resolution:_SymbolLink.Target = try self.resolve(scheme: scheme, 
                    hierarchy: hierarchy,
                    revealed: link.revealed, 
                    imports: imports, 
                    scope: scope, 
                    stems: stems)
                return .init(resolution, visible: link.count)
            }
            catch let error 
            {
                throw _SymbolLink.ResolutionError.init(link, error)
            }
        }
        throw _SymbolLink.ResolutionError.init(link, problem: .empty)
    }
    private 
    func resolve(scheme:Scheme, hierarchy:Hierarchy, revealed:_SymbolLink, 
        imports:Set<Branch.Position<Module>>, 
        scope:_Scope?, 
        stems:Route.Stems) throws -> _SymbolLink.Target
    {
        let scope:_Scope? = hierarchy == .opaque ? scope : nil 
        let link:_SymbolLink
        if case .authority = hierarchy 
        {
            fatalError("unimplemented")
        }
        else 
        {
            link = revealed
        }
        if case .doc = scheme 
        {
            // guard   let namespace:Module.ID = link.first.map(Module.ID.init(_:)), 
            //         let namespace:Tree.Position<Module> = self.namespaces.linked[namespace], 
            //             imports.contains(namespace.contemporary)
            // else 
            // {
            //     throw SelectionError<Branch.Composite>.none 
            // }
            // guard   let link:_SymbolLink = link.suffix 
            // else 
            // {
            //     return .module(namespace.contemporary)
            // }
            // if  let key:Route.Key = stems[namespace.contemporary, straight: link], 
            //     let selection:_Selection<Branch.Composite> = self.lenses.select(key, 
            //         imports: imports)
            // {
            //     return .init(selection)
            // }
        }
        fatalError("unimplemented")
    }
    private 
    func resolve(_ link:_SymbolLink, 
        imports:Set<Branch.Position<Module>>, 
        scope:_Scope?, 
        stems:Route.Stems) -> _SymbolLink.Resolution?
    {
        if  let scope:_Scope, 
            let selection:_Selection<Branch.Composite> = scope.scan(concatenating: link, 
                stems: stems, 
                until: { self.lenses.select($0, imports: imports) })
        {
            return .init(selection)
        }
        // can’t use a namespace as a key field if that namespace was not imported
        guard   let namespace:Module.ID = link.first.map(Module.ID.init(_:)), 
                let namespace:Tree.Position<Module> = self.namespaces.linked[namespace], 
                    imports.contains(namespace.contemporary)
        else 
        {
            return nil
        }
        guard   let link:_SymbolLink = link.suffix 
        else 
        {
            return .module(namespace.contemporary)
        }
        if  let key:Route.Key = stems[namespace.contemporary, link], 
            let selection:_Selection<Branch.Composite> = self.lenses.select(key, 
                imports: imports)
        {
            return .init(selection)
        }
        else 
        {
            return nil
        }
    }
}

    // init(compiling _extension:Extension, 
    //     compiler:__shared Compiler,
    //     scope:_Scope?, 
    //     stems:__shared Route.Stems)
    // {
    //     self.errors = []
    //     _extension.render().transform 
    //     {
    //         (string:String, errors:inout [Error]) -> DOM.Substitution<Link, [UInt8]> in 
            

    //         do 
    //         {
    //             // must attempt to parse absolute first, otherwise 
    //             // '/foo' will parse to ["", "foo"]
    //             let resolved:Link?
    //             // global "doc:" links not supported yet
    //             if !doclink, let uri:URI = try? .init(absolute: suffix)
    //             {
    //                 resolved = try self.resolveWithRedirect(globalLink: uri, 
    //                     lenses: lenses, 
    //                     scope: scope)
    //             }
    //             else 
    //             {
    //                 let uri:URI = try .init(relative: suffix)
                    
    //                 resolved = try self.resolveWithRedirect(visibleLink: uri, nest: nest,
    //                     doclink: doclink,
    //                     lenses: lenses, 
    //                     scope: scope)
    //             }
    //             if let resolved:Link
    //             {
    //                 return .key(resolved)
    //             }
    //             else 
    //             {
    //                 throw Packages.SelectionError.none
    //             }
    //         }
    //         catch let error 
    //         {
    //             errors.append(LinkResolutionError.init(link: string, error: error))
    //             return .segment(HTML.Element<Never>.code(string).node.rendered(as: [UInt8].self))
    //         }
    //     }
    // }