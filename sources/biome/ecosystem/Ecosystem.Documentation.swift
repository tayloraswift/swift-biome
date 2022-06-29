import HTML

extension Ecosystem 
{
    struct Documentation 
    {
        var headlines:[Article.Index: Article.Headline]
        var templates:[Index: Article.Template<Link>]
        
        init(minimumCapacity capacity:Int)
        {
            self.headlines = [:]
            self.templates = .init(minimumCapacity: capacity)
        }
    }
    
    func compileDocumentation(for culture:Package.Index,
        extensions:[[String: Extension]],
        articles:[[Article.Index: Extension]], 
        comments:[Symbol.Index: String], 
        scopes:[Module.Scope], 
        stems:Stems, 
        pins:Package.Pins<Version>)
        -> Documentation
    {
        //  build lexical scopes for each module culture. 
        //  we can store entire packages in the lenses because this method 
        //  is non-mutating!
        let pinned:Package.Pinned = .init(self[culture], at: pins.local)
        let peripherals:[[Index: Extension]] = 
            self.resolveBindings(of: extensions, 
                articles: articles, 
                pinned: pinned,
                scopes: scopes, 
                stems: stems)
        // add upstream lenses 
        let lenses:[[Package.Pinned]] = scopes.map 
        {
            [pinned] + $0.upstream().map { self[$0].pinned(pins.upstream) }
        }
        return self.compile(comments: comments, peripherals: peripherals, 
            lenses: lenses, 
            scopes: scopes, 
            stems: stems)
    }
    
    mutating 
    func updateDocumentation(in culture:Package.Index, 
        upstream:[Package.Index: Version], 
        compiled:Documentation,
        hints:[Symbol.Index: Symbol.Index])
    {
        self[culture].updateDocumentation(compiled)
        self[culture].spreadDocumentation(
            self.recruitMigrants(in: culture, upstream: upstream, 
                sponsors: compiled.templates, 
                hints: hints))
    }
    // `culture` parameter not strictly needed, but we use it to make sure 
    // that ``generateRhetoric(graphs:scopes:)`` did not return ``hints``
    // about other packages
    private 
    func recruitMigrants(in culture:Package.Index,
        upstream:[Package.Index: Version], 
        sponsors:[Index: Article.Template<Link>],
        hints:[Symbol.Index: Symbol.Index]) 
        -> [Symbol.Index: Article.Template<Link>]
    {
        var migrants:[Symbol.Index: Article.Template<Link>] = [:]
        for (member, sponsor):(Symbol.Index, Symbol.Index) in hints
            where !sponsors.keys.contains(.symbol(member))
        {
            assert(member.module.package == culture)
            // if a symbol did not have documentation of its own, 
            // check if it has a sponsor. article templates are copy-on-write 
            // types, so this will not (eagarly) copy storage
            if  let template:Article.Template<Link> = sponsors[.symbol(sponsor)] 
            {
                migrants[member] = template
            }
            // note: empty doccomments are omitted from the template buffer
            else if culture != sponsor.module.package
            {
                let template:Article.Template<Link> = self[sponsor.module.package]
                    .pinned(upstream)
                    .template(sponsor)
                if !template.isEmpty
                {
                    migrants[member] = template
                }
            }
        }
        return migrants
    }
}

extension Ecosystem
{
    private 
    func resolveBindings(of extensions:[[String: Extension]], 
        articles:[[Article.Index: Extension]],
        pinned:Package.Pinned,
        scopes:[Module.Scope], 
        stems:Stems) 
        -> [[Index: Extension]]
    {
        zip(scopes, zip(articles, extensions)).map
        {
            let (       scope, ( articles,                           extensions)):
                (Module.Scope, ([Article.Index: Extension], [String: Extension])) = $0
            
            var bindings:[Index: Extension] = [:]
                bindings.reserveCapacity(articles.count + extensions.count)
            for (index, article):(Article.Index, Extension) in articles 
            {
                bindings[.article(index)] = article
            }
            for (binding, article):(String, Extension) in extensions
            {
                guard let binding:Index = self.resolveWithRedirect(binding: binding, 
                    pinned: pinned,
                    scope: scope, 
                    stems: stems)
                else 
                {
                    fatalError("unimplemented")
                }
                // TODO: emit warning for colliding extensions
                bindings[binding] = article 
            }
            return bindings
        }
    }
    private 
    func resolveWithRedirect(binding string:String, 
        pinned:Package.Pinned,
        scope:Module.Scope,
        stems:Stems) 
        -> Index?
    {
        if  let uri:URI = try? .init(relative: string), 
            case (.index(let index), _)? = try? self.resolveWithRedirect(
                visibleLink: uri,
                lenses: [pinned], 
                scope: scope, 
                stems: stems)
        {
            return index 
        }
        else 
        {
            return nil 
        }
    }
}
extension Ecosystem
{
    private 
    func compile(comments:[Symbol.Index: String], 
        peripherals:[[Index: Extension]], 
        lenses:[[Package.Pinned]],
        scopes:[Module.Scope], 
        stems:Stems)
        -> Documentation
    {
        var documentation:Documentation = .init(minimumCapacity: comments.count + 
            peripherals.reduce(0) { $0 + $1.count })
        self.compile(&documentation,
            peripherals: peripherals, 
            lenses: lenses, 
            scopes: scopes, 
            stems: stems)
        self.compile(&documentation,
            comments: comments, 
            lenses: lenses, 
            scopes: scopes, 
            stems: stems)
        return documentation
    }
    private
    func compile(_ documentation:inout Documentation, 
        peripherals:[[Index: Extension]], 
        lenses:[[Package.Pinned]],
        scopes:[Module.Scope], 
        stems:Stems)
    {
        for ((lenses, scope), assigned):(([Package.Pinned], Module.Scope), [Index: Extension]) in 
            zip(zip(lenses, scopes), peripherals)
        {
            for (target, article):(Index, Extension) in assigned
            {
                documentation.templates[target] = self.compile(article, 
                    lenses: lenses, 
                    scope: scope, 
                    nest: self.nest(target),
                    stems: stems)
                
                if case .article(let index) = target 
                {
                    documentation.headlines[index] = .init(
                        formatted: article.headline.rendered(as: [UInt8].self),
                        plain: article.headline.plainText)
                }
            } 
        }
    }
    private
    func compile(_ documentation:inout Documentation, 
        comments:[Symbol.Index: String], 
        lenses:[[Package.Pinned]],
        scopes:[Module.Scope], 
        stems:Stems)
    {
        // need to turn the lexica into something we can select from a flattened 
        // comments dictionary 
        let contexts:[Module.Index: Int] = 
            .init(uniqueKeysWithValues: zip(scopes.lazy.map(\.culture), scopes.indices))
        for (symbol, comment):(Symbol.Index, String) in comments
        {
            guard let context:Int = contexts[symbol.module] 
            else 
            {
                fatalError("unreachable")
            }
            
            let comment:Extension = .init(markdown: comment)
            let target:Index = .symbol(symbol)
            
            documentation.templates[target] = self.compile(comment, 
                lenses: lenses[context], 
                scope: scopes[context], 
                nest: self.nest(target),
                stems: stems)
        } 
    }
    private 
    func compile(_ article:Extension, 
        lenses:[Package.Pinned],
        scope:Module.Scope,
        nest:Symbol.Nest?,
        stems:Stems)
        -> Article.Template<Link>
    {
        let scope:Module.Scope = scope.import(article.metadata.imports)
        return article.render().transform 
        {
            (string:String, errors:inout [Error]) -> DOM.Substitution<Link, [UInt8]> in 
            
            let doclink:Bool
            let suffix:Substring 
            if  let start:String.Index = 
                    string.index(string.startIndex, offsetBy: 4, limitedBy: string.endIndex), 
                string[..<start] == "doc:"
            {
                doclink = true 
                suffix = string[start...]
            }
            else 
            {
                doclink = false 
                suffix = string[...]
            }
            do 
            {
                // must attempt to parse absolute first, otherwise 
                // '/foo' will parse to ["", "foo"]
                let resolved:(selection:Selection, visible:Int)?
                // global "doc:" links not supported yet
                if !doclink, let uri:URI = try? .init(absolute: suffix)
                {
                    resolved = try self.resolveWithRedirect(globalLink: uri, 
                        lenses: lenses, 
                        scope: scope, 
                        stems: stems)
                }
                else 
                {
                    let uri:URI = try .init(relative: suffix)
                    
                    resolved = try self.resolveWithRedirect(visibleLink: uri, nest: nest,
                        doclink: doclink,
                        lenses: lenses, 
                        scope: scope, 
                        stems: stems)
                }
                switch resolved
                {
                case nil:
                    throw LinkResolutionError.none(string)
                case (.index(let target), let visible)?:
                    return .key(.init(target, visible: visible))
                case (.composites(let possibilities), _)?:
                    throw LinkResolutionError.many(string, possibilities)
                }
            }
            catch let error 
            {
                errors.append(error)
                return .segment(HTML.Element<Never>.code(string).rendered(as: [UInt8].self))
            }
        }
    }
    private 
    func nest(_ target:Index) -> Symbol.Nest?
    {
        guard case .composite(let composite) = target 
        else 
        {
            return nil 
        }
        if  let host:Symbol.Index = composite.host 
        {
            let host:Symbol = self[host]
            return .init(namespace: host.namespace, prefix: [String].init(host.path))
        }
        else 
        {
            return self[composite.base].nest
        }
    }
    
    private 
    func resolveWithRedirect(globalLink uri:URI, 
        lenses:[Package.Pinned], 
        scope:Module.Scope,
        stems:Stems) 
        throws -> (selection:Selection, visible:Int)? 
    {
        let (global, fold):([String], Int) = uri.path.normalized
        
        guard   let destination:Package.ID = global.first.map(Package.ID.init(_:)), 
                let destination:Package.Index = self.indices[destination]
        else 
        {
            return nil 
        }
        
        let qualified:ArraySlice<String> = _move(global).dropFirst()
        
        guard let namespace:Module.ID = qualified.first.map(Module.ID.init(_:)) 
        else 
        {
            return (.package(destination), 1)
        }
        guard let namespace:Module.Index = self[destination].modules.indices[namespace]
        else 
        {
            return nil
        }
        
        let implicit:ArraySlice<String> = _move(qualified).dropFirst()
        if  implicit.isEmpty 
        {
            return (.module(namespace), 1)
        }
        
        let link:Symbol.Link = try .init(path: (implicit, fold), query: uri.query ?? [])
        
        if  case let (package, pins)? = self.localize(destination: destination, 
                lens: link.query.lens),
            let route:Route = stems[namespace, link.revealed],
            case let (selection, _)? = self.selectWithRedirect(from: route, 
                lens: .init(package, at: pins.local), 
                by: link.disambiguator)
        {
            return (selection, link.count)
        }
        else 
        {
            return nil
        }
    }
    private 
    func resolveWithRedirect(visibleLink uri:URI, 
        nest:Symbol.Nest? = nil, 
        doclink:Bool = false, 
        lenses:[Package.Pinned],
        scope:Module.Scope,
        stems:Stems) 
        throws -> (selection:Selection, visible:Int)? 
    {
        let (path, fold):([String], Int) = uri.path.normalized 
        if  doclink,  
            let route:Route = stems[scope.culture, path],
            let article:Article.Index = 
                self[scope.culture.package].articles.indices[route]
        {
            return (.article(article), path.endIndex - fold)
        }
        let expression:Symbol.Link = 
            try .init(path: (path, fold), query: uri.query ?? [])
        if      let selection:Selection = self.resolve(
                    visibleLink: expression.revealed, nest: nest, 
                    lenses: lenses, 
                    scope: scope, 
                    stems: stems)
        {
            return (selection, expression.count)
        }
        else if let outed:Symbol.Link = expression.revealed.outed,
                let selection:Selection = self.resolve(
                    visibleLink: outed, nest: nest, 
                    lenses: lenses, 
                    scope: scope, 
                    stems: stems)
        {
            return (selection, expression.count)
        }
        else 
        {
            return nil
        }
    }
    private 
    func resolve(visibleLink link:Symbol.Link, 
        nest:Symbol.Nest? = nil, 
        lenses:[Package.Pinned],
        scope:Module.Scope,
        stems:Stems) 
        -> Selection? 
    {
        //  check if the first component refers to a module. it can be the same 
        //  as its own culture, or one of its dependencies. 
        //  we can store a module id in a ``Symbol/Link``, because every 
        //  ``Module/ID`` is a valid ``Symbol/Link/Component``.
        if  let namespace:Module.ID = (link.first?.string).map(Module.ID.init(_:)), 
            let namespace:Module.Index = scope[namespace]
        {
            if  let implicit:Symbol.Link = link.suffix 
            {
                return self.resolve(relativeLink: implicit, 
                    namespace: namespace, 
                    lenses: lenses,
                    scope: scope, 
                    stems: stems)
            }
            else 
            {
                return .module(namespace)
            }
        }
        
        if  let nest:Symbol.Nest,
            let relative:Selection = self.resolve(relativeLink: link, 
                namespace: nest.namespace, 
                prefix: nest.prefix, 
                lenses: lenses, 
                scope: scope, 
                stems: stems)
        {
            return relative
        }
        // primary culture takes precedence
        if  let absolute:Selection = self.resolve(relativeLink: link, 
                namespace: scope.culture, 
                lenses: lenses, 
                scope: scope, 
                stems: stems) 
        {
            return absolute
        }
        var imported:Selection? = nil 
        for namespace:Module.Index in scope.filter where namespace != scope.culture 
        {
            if  let absolute:Selection = self.resolve(relativeLink: link, 
                    namespace: namespace, 
                    lenses: lenses, 
                    scope: scope, 
                    stems: stems) 
            {
                if case nil = imported 
                {
                    imported = absolute
                }
                else 
                {
                    // name collision
                    return nil 
                }
            }
        }
        return imported
    }
    private 
    func resolve(relativeLink link:Symbol.Link, 
        namespace:Module.Index, 
        prefix:[String] = [], 
        lenses:[Package.Pinned], 
        scope:Module.Scope,
        stems:Stems) 
        -> Selection?
    {
        guard let route:Route = stems[namespace, prefix, link]
        else 
        {
            return nil
        }
        let disambiguator:Symbol.Disambiguator = link.disambiguator
        return self.select(from: route, lenses: lenses)
        {
            scope.contains($0.culture) && self.filter($0, by: disambiguator)
        }
    }
}
