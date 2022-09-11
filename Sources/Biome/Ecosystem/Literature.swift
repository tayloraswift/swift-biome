import SymbolGraphs 
import DOM
import URI

enum ExpandedLink:Hashable, Sendable 
{
    case article(Tree.Position<Article>)
    case package(Package.Index)
    case implicit                        ([Tree.Position<Symbol>])
    case qualified(Tree.Position<Module>, [Tree.Position<Symbol>] = [])
}
enum ResolvedLink:Hashable, Sendable 
{
    case article(Branch.Position<Article>)
    case module(Branch.Position<Module>)
    case package(Package.Index)
    case composite(Branch.Composite)
}

struct Literature 
{
    private(set) 
    var articles:[(Branch.Position<Article>, CompiledDocumentation)]
    private(set) 
    var symbols:[(Branch.Position<Symbol>, Documentation<CompiledDocumentation, Symbol.Index>)]
    private(set) 
    var modules:[(Branch.Position<Module>, CompiledDocumentation)]
    private(set) 
    var package:CompiledDocumentation?

    init(compiling graphs:__owned [SymbolGraph], 
        interfaces:__owned [ModuleInterface], 
        version:_Version, 
        context:__shared Packages, 
        stems:__shared Route.Stems)
    {
        guard let culture:Package.Index = interfaces.first?.culture.package 
        else 
        {
            //return [:]
            fatalError("unimplemented")
        }

        self.articles = []
        self.symbols = []
        self.modules = []
        self.package = nil

        let local:Package._Pinned = .init(context[culture], version: version)

        var pruned:Int = 0
        var comments:[Tree.Position<Symbol>: Documentation<String, Tree.Position<Symbol>>] = [:]
        for (graph, interface):(SymbolGraph, ModuleInterface) in zip(_move graphs, interfaces)
        {
            for (position, vertex):(Tree.Position<Symbol>?, SymbolGraph.Vertex<Int>) in 
                zip(interface.citizenSymbols, graph.vertices)
            {
                guard   let position:Tree.Position<Symbol>,
                        let documentation:Documentation<String, Tree.Position<Symbol>> = 
                            vertex.documentation?.flatMap({ interface.symbols[$0] })
                else 
                {
                    continue 
                }
                if  case .extends(let origin?, with: let comment) = documentation, 
                        origin.contemporary.culture != interface.culture,
                    case .extends(_, with: comment)? = comments[origin]
                {
                    // inherited a comment from a *different* module. 
                    // if it were from the same module, symbolgraphconvert 
                    // should have deleted it. 
                    comments[position] = .inherits(origin)
                    pruned += 1
                }
                else 
                {
                    comments[position] = documentation
                }
            }

            let compiler:Compiler = .init(local: local, upstream: interface.pins.map 
                {
                    .init(context[$0.key], version: $0.value)
                }, 
                namespaces: interface.namespaces)

            for (position, _extension):(Tree.Position<Article>?, Extension) in 
                zip(interface.citizenArticles, interface._extensions)
            {
                let imports:Set<Branch.Position<Module>> = 
                    interface.namespaces.import(_extension.metadata.imports)
                // TODO: handle merge behavior block directive 
                if let position:Tree.Position<Article> 
                {
                    self.articles.append((position.contemporary, compiler.compile(_move _extension, 
                        imports: imports, 
                        scope: .init(interface.culture), 
                        stems: stems)))
                }
                else if let binding:String = _extension.binding, 
                        let binding:URI = try? .init(relative: binding),
                        let binding:_SymbolLink = try? .init(binding)
                {
                    switch local.resolve(binding.revealed, 
                        scope: .init(interface.culture), 
                        stems: stems)
                    {
                    case nil: 
                        break 
                    case .package(_): 
                        self.package = compiler.compile(_move _extension, 
                            imports: imports, 
                            scope: nil, 
                            stems: stems)
                    
                    case .module(let module): 
                        self.modules.append((module, compiler.compile(_move _extension, 
                            imports: imports, 
                            scope: .init(module), 
                            stems: stems)))
                    case .composite(_):
                        break 
                    case .composites(_):
                        break 
                    }
                }
            }
        }
        if pruned != 0 
        {
            print("pruned \(pruned) duplicate comments")
        }

        var skipped:Int = 0,
            dropped:Int = 0
        comments = comments.compactMapValues 
        {
            if case .inherits(var origin) = $0 
            {
                // fast-forward until we either reach a package boundary, 
                // or a local symbol that has documentation
                var visited:Set<Branch.Position<Symbol>> = []
                fastforwarding:
                while origin.package == culture
                {
                    if  case _? = visited.update(with: origin.contemporary)
                    {
                        fatalError("detected cycle in doccomment inheritance graph")
                    }
                    switch comments[origin] 
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
        if skipped != 0 
        {
            print("shortened \(skipped) doccomment inheritance links")
        }
        if dropped != 0 
        {
            print("pruned \(dropped) nil-terminating doccomment inheritance chains")
        }
        //return comments 
        fatalError("unimplemented")
    }
}

struct Compiler 
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
    let lenses:Lenses 
    private 
    let namespaces:Namespaces

    init(local:Package._Pinned, upstream:[Package._Pinned], namespaces:Namespaces)
    {
        self.lenses = .init(local: local, upstream: upstream)
        self.namespaces = namespaces
    }

    func compile(_ _extension:__owned Extension, 
        imports:Set<Branch.Position<Module>>, 
        scope:_Scope?, 
        stems:Route.Stems) -> CompiledDocumentation
    {
        fatalError("unimplemented")
    }

    private 
    func resolve(_ link:_SymbolLink, 
        imports:Set<Branch.Position<Module>>, 
        scope:_Scope?, 
        stems:Route.Stems)
        -> _SymbolLink.Resolution?
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
                let namespace:Tree.Position<Module> = namespaces.linked[namespace], 
                    imports.contains(namespace.contemporary)
        else 
        {
            return nil
        }
        guard let link:_SymbolLink = link.suffix 
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

struct CompiledDocumentation
{
    struct Link:Hashable, Sendable
    {
        let target:ResolvedLink
        let visible:Int
        
        init(_ target:ResolvedLink, visible:Int)
        {
            self.target = target 
            self.visible = visible
        }
    }

    let card:DOM.Flattened<Link>
    let body:DOM.Flattened<Link>
    var errors:[any Error]

    // init(compiling _extension:Extension, 
    //     compiler:__shared Compiler,
    //     scope:_Scope?, 
    //     stems:__shared Route.Stems)
    // {
    //     self.errors = []
    //     _extension.render().transform 
    //     {
    //         (string:String, errors:inout [Error]) -> DOM.Substitution<Link, [UInt8]> in 
            
    //         let doclink:Bool
    //         let suffix:Substring 
    //         if  let start:String.Index = 
    //                 string.index(string.startIndex, offsetBy: 4, limitedBy: string.endIndex), 
    //             string[..<start] == "doc:"
    //         {
    //             doclink = true 
    //             suffix = string[start...]
    //         }
    //         else 
    //         {
    //             doclink = false 
    //             suffix = string[...]
    //         }
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
}