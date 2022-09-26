import URI

public 
enum Scheme 
{
    case symbol
    case doc
}
struct Resolver 
{
    private 
    struct Lenses:RandomAccessCollection
    {
        let context:AnisotropicContext
        private 
        let upstream:[Package.Pinned]

        var startIndex:Int 
        {
            -1 
        }
        var endIndex:Int
        {
            self.upstream.endIndex
        }
        subscript(index:Int) -> Package.Pinned 
        {
            _read 
            {
                yield index < 0 ? self.context.local : self.upstream[index]
            }
        }

        init(_ context:AnisotropicContext)
        {
            self.upstream = .init(context.upstream.values) 
            self.context = context
        }

        func select(_ key:Route, 
            disambiguator:_SymbolLink.Disambiguator, 
            imports:Set<Atom<Module>>)
            -> _Selection<Composite>?
        {
            var selection:_Selection<Composite>? = nil 
            for lens:Package.Pinned in self
            {
                lens.routes.select(key)
                {
                    if  imports.contains($0.culture), 
                        lens.exists($0), 
                        disambiguator.matches($0, context: self.context)
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
    let linked:[Package.ID: Package.Pinned]
    let namespaces:Namespaces

    init(local:Package.Pinned, pins:__shared [Package.Index: Version], 
        namespaces:Namespaces, 
        context:__shared Packages)
    {
        let context:AnisotropicContext = .init(local: _move local, pins: pins, context: context)
        var linked:[Package.ID: Package.Pinned] = .init(minimumCapacity: pins.count + 1)
            linked[context.local.package.id] = context.local 
        for upstream:Package.Pinned in context.upstream.values 
        {
            linked[upstream.package.id] = upstream
        }
        self.namespaces = namespaces
        self.lenses = .init(_move context)
        self.linked = linked
    }

    var context:AnisotropicContext
    {
        _read 
        {
            yield self.lenses.context
        }
    }
    var local:Package.Pinned 
    {
        _read 
        {
            yield self.context.local
        }
    }

    func resolve(expression:String, 
        imports:Set<Atom<Module>>, 
        scope:_Scope?, 
        stems:Route.Stems) throws -> GlobalLink.Presentation
    {
        let schemeless:Substring 
        let scheme:Scheme 
        if  let colon:String.Index = expression.firstIndex(of: ":")
        {
            if expression[..<colon] == "doc" 
            {
                scheme = .doc 
            }
            else 
            {
                throw _SymbolLink.ResolutionError.init(expression, problem: .scheme)
            }
            schemeless = expression[expression.index(after: colon)...]
        }
        else 
        {
            scheme = .symbol
            schemeless = expression[...]
        }
        var slashes:Int = 0
        for index:String.Index in schemeless.indices 
        {
            if  slashes <  2, schemeless[index] == "/" 
            {
                slashes += 1
                continue 
            }
            do 
            {
                let uri:URI = try .init(relative: schemeless[index...])
                if  slashes > 1 
                {
                    var link:GlobalLink = .init(uri)
                    // uri begins with an authority component (package residency).
                    // '//swift-foo/foomodule/footype.foomember(_:)'.
                    guard   let residency:Package.ID = link.descend().map(Package.ID.init(_:)),
                            let residency:Package.Pinned = self.linked[residency]
                    else 
                    {
                        throw _SymbolLink.ResolutionProblem.residency
                    }

                    // TODO: we do not support version/branch/tag components, 
                    // but if we did, this is where we would add it.
                    // ...

                    guard let link:_SymbolLink = try .init(link)
                    else 
                    {
                        return .package(residency.nationality)
                    }
                    // if there are additional path components after the package name, 
                    // then the package name is irrelevant, since all module namespaces 
                    // are already unique within a resolution context.
                    return try self.resolve(scheme: scheme, 
                        symbolLink: link, 
                        imports: imports, 
                        scope: nil, 
                        stems: stems)
                }
                else if let link:_SymbolLink = try .init(uri)
                {
                    let scope:_Scope? = slashes == 0 ? scope : nil
                    return try self.resolve(scheme: scheme, 
                        symbolLink: link, 
                        imports: imports, 
                        scope: scope, 
                        stems: stems)
                }
            }
            catch let error 
            {
                throw _SymbolLink.ResolutionError.init(expression, error)
            }
        }
        throw _SymbolLink.ResolutionError.init(expression, problem: .empty)
    }
    private 
    func resolve(scheme:Scheme, symbolLink link:_SymbolLink, 
        imports:Set<Atom<Module>>, 
        scope:_Scope?, 
        stems:Route.Stems) throws -> GlobalLink.Presentation
    {
        if  case .doc = scheme, 
            let article:Atom<Article> = self.resolve(docLink: link, 
                imports: imports, 
                scope: scope, 
                stems: stems)
        {
            return .article(article)
        }
        let link:_SymbolLink = link.disambiguated()
        let resolution:_SymbolLink.Resolution?
        if  let nationality:_SymbolLink.Nationality = link.nationality
        {
            guard let local:Package.Pinned = self.linked[nationality.id]
            else 
            {
                throw _SymbolLink.ResolutionProblem.nationality
            }
            // we *could* support re-slicing a pinned package to a version that 
            // is an ancestor of the current (branch, revision) tuple. 
            // but currently, we do not.
            if  let version:Version.Selector = nationality.version, 
                let version:Version = local.package.tree.find(version), 
                    version != local.version
            {
                throw _SymbolLink.ResolutionProblem.nationalVersion
            }
            // filtering by import set is still useful, even with a nationality
            resolution = local.resolve(link.revealed, scope: scope, stems: stems)
            {
                imports.contains($0.culture) && 
                local.exists($0) && 
                link.disambiguator.matches($0, context: self.context)
            }
        }
        else 
        {
            resolution = self.resolve(symbolLink: link.revealed, 
                imports: imports, 
                scope: scope, 
                stems: stems)
        }
        return .init(try .init(resolution), visible: link.count)
    }
    private 
    func resolve(docLink link:_SymbolLink, 
        imports:Set<Atom<Module>>, 
        scope:_Scope?, 
        stems:Route.Stems) -> Atom<Article>?
    {
        if  let scope:_Scope, 
            let article:Atom<Article>.Position = scope.scan(concatenating: link, 
                stems: stems, 
                until: { self.context[$0.namespace.nationality]?.articles.find(.init($0)) })
        {
            return article.atom
        }
        // can’t use a namespace as a key field if that namespace was not imported
        if  let path:_SymbolLink = link.suffix,
            let namespace:Atom<Module>.Position = self.namespaces.linked[.init(link.first)], 
                imports.contains(namespace.atom), 
            let pinned:Package.Pinned = self.context[namespace.nationality],
            let article:Route = stems[namespace.atom, straight: path], 
            let article:Atom<Article>.Position = pinned.articles.find(.init(article))
        {
            return article.atom
        }
        else 
        {
            return nil
        }
    }
    private 
    func resolve(symbolLink link:_SymbolLink, 
        imports:Set<Atom<Module>>, 
        scope:_Scope?, 
        stems:Route.Stems) -> _SymbolLink.Resolution?
    {
        if  let scope:_Scope, 
            let selection:_Selection<Composite> = scope.scan(concatenating: link, 
                stems: stems, 
                until: 
                { 
                    self.lenses.select($0, disambiguator: link.disambiguator, imports: imports) 
                })
        {
            return .init(selection)
        }
        // can’t use a namespace as a key field if that namespace was not imported
        guard   let namespace:Atom<Module>.Position = self.namespaces.linked[.init(link.first)], 
                    imports.contains(namespace.atom)
        else 
        {
            return nil
        }
        guard   let link:_SymbolLink = link.suffix 
        else 
        {
            return .module(namespace.atom)
        }
        if  let key:Route = stems[namespace.atom, link], 
            let selection:_Selection<Composite> = 
                self.lenses.select(key, disambiguator: link.disambiguator, imports: imports)
        {
            return .init(selection)
        }
        else 
        {
            return nil
        }
    }
}
